//===-- SIRegisterInfo.cpp - SI Register Information ---------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Modifications Copyright (c) 2019 Advanced Micro Devices, Inc. All rights reserved.
// Notified per clause 4(b) of the license.
//
//===----------------------------------------------------------------------===//
//
/// \file
/// SI implementation of the TargetRegisterInfo class.
//
//===----------------------------------------------------------------------===//

#include "SIRegisterInfo.h"
#include "AMDGPURegisterBankInfo.h"
#include "AMDGPUSubtarget.h"
#include "SIInstrInfo.h"
#include "SIMachineFunctionInfo.h"
#include "MCTargetDesc/AMDGPUInstPrinter.h"
#include "MCTargetDesc/AMDGPUMCTargetDesc.h"
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/MachineDominators.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/RegisterScavenging.h"
#include "llvm/CodeGen/SlotIndexes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/LLVMContext.h"

using namespace llvm;

static bool hasPressureSet(const int *PSets, unsigned PSetID) {
  for (unsigned i = 0; PSets[i] != -1; ++i) {
    if (PSets[i] == (int)PSetID)
      return true;
  }
  return false;
}

void SIRegisterInfo::classifyPressureSet(unsigned PSetID, unsigned Reg,
                                         BitVector &PressureSets) const {
  for (MCRegUnitIterator U(Reg, this); U.isValid(); ++U) {
    const int *PSets = getRegUnitPressureSets(*U);
    if (hasPressureSet(PSets, PSetID)) {
      PressureSets.set(PSetID);
      break;
    }
  }
}

static cl::opt<bool> EnableSpillSGPRToVGPR(
  "amdgpu-spill-sgpr-to-vgpr",
  cl::desc("Enable spilling VGPRs to SGPRs"),
  cl::ReallyHidden,
  cl::init(true));

SIRegisterInfo::SIRegisterInfo(const GCNSubtarget &ST) :
  AMDGPURegisterInfo(),
  ST(ST),
  SGPRPressureSets(getNumRegPressureSets()),
  VGPRPressureSets(getNumRegPressureSets()),
  AGPRPressureSets(getNumRegPressureSets()),
  SpillSGPRToVGPR(EnableSpillSGPRToVGPR),
  isWave32(ST.isWave32()) {
  unsigned NumRegPressureSets = getNumRegPressureSets();

  SGPRSetID = NumRegPressureSets;
  VGPRSetID = NumRegPressureSets;
  AGPRSetID = NumRegPressureSets;

  for (unsigned i = 0; i < NumRegPressureSets; ++i) {
    classifyPressureSet(i, AMDGPU::SGPR0, SGPRPressureSets);
    classifyPressureSet(i, AMDGPU::VGPR0, VGPRPressureSets);
    classifyPressureSet(i, AMDGPU::AGPR0, AGPRPressureSets);
  }

  // Determine the number of reg units for each pressure set.
  std::vector<unsigned> PressureSetRegUnits(NumRegPressureSets, 0);
  for (unsigned i = 0, e = getNumRegUnits(); i != e; ++i) {
    const int *PSets = getRegUnitPressureSets(i);
    for (unsigned j = 0; PSets[j] != -1; ++j) {
      ++PressureSetRegUnits[PSets[j]];
    }
  }

  unsigned VGPRMax = 0, SGPRMax = 0, AGPRMax = 0;
  for (unsigned i = 0; i < NumRegPressureSets; ++i) {
    if (isVGPRPressureSet(i) && PressureSetRegUnits[i] > VGPRMax) {
      VGPRSetID = i;
      VGPRMax = PressureSetRegUnits[i];
      continue;
    }
    if (isSGPRPressureSet(i) && PressureSetRegUnits[i] > SGPRMax) {
      SGPRSetID = i;
      SGPRMax = PressureSetRegUnits[i];
    }
    if (isAGPRPressureSet(i) && PressureSetRegUnits[i] > AGPRMax) {
      AGPRSetID = i;
      AGPRMax = PressureSetRegUnits[i];
      continue;
    }
  }

  assert(SGPRSetID < NumRegPressureSets &&
         VGPRSetID < NumRegPressureSets &&
         AGPRSetID < NumRegPressureSets);
}

unsigned SIRegisterInfo::reservedPrivateSegmentBufferReg(
  const MachineFunction &MF) const {
  unsigned BaseIdx = alignDown(ST.getMaxNumSGPRs(MF), 4) - 4;
  unsigned BaseReg(AMDGPU::SGPR_32RegClass.getRegister(BaseIdx));
  return getMatchingSuperReg(BaseReg, AMDGPU::sub0, &AMDGPU::SGPR_128RegClass);
}

static unsigned findPrivateSegmentWaveByteOffsetRegIndex(unsigned RegCount) {
  unsigned Reg;

  // Try to place it in a hole after PrivateSegmentBufferReg.
  if (RegCount & 3) {
    // We cannot put the segment buffer in (Idx - 4) ... (Idx - 1) due to
    // alignment constraints, so we have a hole where can put the wave offset.
    Reg = RegCount - 1;
  } else {
    // We can put the segment buffer in (Idx - 4) ... (Idx - 1) and put the
    // wave offset before it.
    Reg = RegCount - 5;
  }

  return Reg;
}

unsigned SIRegisterInfo::reservedPrivateSegmentWaveByteOffsetReg(
  const MachineFunction &MF) const {
  unsigned Reg = findPrivateSegmentWaveByteOffsetRegIndex(ST.getMaxNumSGPRs(MF));
  return AMDGPU::SGPR_32RegClass.getRegister(Reg);
}

BitVector SIRegisterInfo::getReservedRegs(const MachineFunction &MF) const {
  BitVector Reserved(getNumRegs());

  // EXEC_LO and EXEC_HI could be allocated and used as regular register, but
  // this seems likely to result in bugs, so I'm marking them as reserved.
  reserveRegisterTuples(Reserved, AMDGPU::EXEC);
  reserveRegisterTuples(Reserved, AMDGPU::FLAT_SCR);

  // M0 has to be reserved so that llvm accepts it as a live-in into a block.
  reserveRegisterTuples(Reserved, AMDGPU::M0);

  // Reserve src_vccz, src_execz, src_scc.
  reserveRegisterTuples(Reserved, AMDGPU::SRC_VCCZ);
  reserveRegisterTuples(Reserved, AMDGPU::SRC_EXECZ);
  reserveRegisterTuples(Reserved, AMDGPU::SRC_SCC);

  // Reserve the memory aperture registers.
  reserveRegisterTuples(Reserved, AMDGPU::SRC_SHARED_BASE);
  reserveRegisterTuples(Reserved, AMDGPU::SRC_SHARED_LIMIT);
  reserveRegisterTuples(Reserved, AMDGPU::SRC_PRIVATE_BASE);
  reserveRegisterTuples(Reserved, AMDGPU::SRC_PRIVATE_LIMIT);

  // Reserve src_pops_exiting_wave_id - support is not implemented in Codegen.
  reserveRegisterTuples(Reserved, AMDGPU::SRC_POPS_EXITING_WAVE_ID);

  // Reserve xnack_mask registers - support is not implemented in Codegen.
  reserveRegisterTuples(Reserved, AMDGPU::XNACK_MASK);

  // Reserve lds_direct register - support is not implemented in Codegen.
  reserveRegisterTuples(Reserved, AMDGPU::LDS_DIRECT);

  // Reserve Trap Handler registers - support is not implemented in Codegen.
  reserveRegisterTuples(Reserved, AMDGPU::TBA);
  reserveRegisterTuples(Reserved, AMDGPU::TMA);
  reserveRegisterTuples(Reserved, AMDGPU::TTMP0_TTMP1);
  reserveRegisterTuples(Reserved, AMDGPU::TTMP2_TTMP3);
  reserveRegisterTuples(Reserved, AMDGPU::TTMP4_TTMP5);
  reserveRegisterTuples(Reserved, AMDGPU::TTMP6_TTMP7);
  reserveRegisterTuples(Reserved, AMDGPU::TTMP8_TTMP9);
  reserveRegisterTuples(Reserved, AMDGPU::TTMP10_TTMP11);
  reserveRegisterTuples(Reserved, AMDGPU::TTMP12_TTMP13);
  reserveRegisterTuples(Reserved, AMDGPU::TTMP14_TTMP15);

  // Reserve null register - it shall never be allocated
  reserveRegisterTuples(Reserved, AMDGPU::SGPR_NULL);

  // Disallow vcc_hi allocation in wave32. It may be allocated but most likely
  // will result in bugs.
  if (isWave32) {
    Reserved.set(AMDGPU::VCC);
    Reserved.set(AMDGPU::VCC_HI);
  }

  unsigned MaxNumSGPRs = ST.getMaxNumSGPRs(MF);
  unsigned TotalNumSGPRs = AMDGPU::SGPR_32RegClass.getNumRegs();
  for (unsigned i = MaxNumSGPRs; i < TotalNumSGPRs; ++i) {
    unsigned Reg = AMDGPU::SGPR_32RegClass.getRegister(i);
    reserveRegisterTuples(Reserved, Reg);
  }

  unsigned MaxNumVGPRs = ST.getMaxNumVGPRs(MF);
  unsigned TotalNumVGPRs = AMDGPU::VGPR_32RegClass.getNumRegs();
  for (unsigned i = MaxNumVGPRs; i < TotalNumVGPRs; ++i) {
    unsigned Reg = AMDGPU::VGPR_32RegClass.getRegister(i);
    reserveRegisterTuples(Reserved, Reg);
    Reg = AMDGPU::AGPR_32RegClass.getRegister(i);
    reserveRegisterTuples(Reserved, Reg);
  }

  // Reserve all the rest AGPRs if there are no instructions to use it.
  if (!ST.hasMAIInsts()) {
    for (unsigned i = 0; i < MaxNumVGPRs; ++i) {
      unsigned Reg = AMDGPU::AGPR_32RegClass.getRegister(i);
      reserveRegisterTuples(Reserved, Reg);
    }
  }

  const SIMachineFunctionInfo *MFI = MF.getInfo<SIMachineFunctionInfo>();

  unsigned ScratchWaveOffsetReg = MFI->getScratchWaveOffsetReg();
  if (ScratchWaveOffsetReg != AMDGPU::NoRegister) {
    // Reserve 1 SGPR for scratch wave offset in case we need to spill.
    reserveRegisterTuples(Reserved, ScratchWaveOffsetReg);
  }

  unsigned ScratchRSrcReg = MFI->getScratchRSrcReg();
  if (ScratchRSrcReg != AMDGPU::NoRegister) {
    // Reserve 4 SGPRs for the scratch buffer resource descriptor in case we need
    // to spill.
    // TODO: May need to reserve a VGPR if doing LDS spilling.
    reserveRegisterTuples(Reserved, ScratchRSrcReg);
    assert(!isSubRegister(ScratchRSrcReg, ScratchWaveOffsetReg));
  }

  // We have to assume the SP is needed in case there are calls in the function,
  // which is detected after the function is lowered. If we aren't really going
  // to need SP, don't bother reserving it.
  unsigned StackPtrReg = MFI->getStackPtrOffsetReg();

  if (StackPtrReg != AMDGPU::NoRegister) {
    reserveRegisterTuples(Reserved, StackPtrReg);
    assert(!isSubRegister(ScratchRSrcReg, StackPtrReg));
  }

  unsigned FrameReg = MFI->getFrameOffsetReg();
  if (FrameReg != AMDGPU::NoRegister) {
    reserveRegisterTuples(Reserved, FrameReg);
    assert(!isSubRegister(ScratchRSrcReg, FrameReg));
  }

  for (unsigned Reg : MFI->WWMReservedRegs) {
    reserveRegisterTuples(Reserved, Reg);
  }

  // FIXME: Stop using reserved registers for this.
  for (MCPhysReg Reg : MFI->getAGPRSpillVGPRs())
    reserveRegisterTuples(Reserved, Reg);

  for (MCPhysReg Reg : MFI->getVGPRSpillAGPRs())
    reserveRegisterTuples(Reserved, Reg);

  return Reserved;
}

bool SIRegisterInfo::canRealignStack(const MachineFunction &MF) const {
  const SIMachineFunctionInfo *Info = MF.getInfo<SIMachineFunctionInfo>();
  // On entry, the base address is 0, so it can't possibly need any more
  // alignment.

  // FIXME: Should be able to specify the entry frame alignment per calling
  // convention instead.
  if (Info->isEntryFunction())
    return false;

  return TargetRegisterInfo::canRealignStack(MF);
}

bool SIRegisterInfo::requiresRegisterScavenging(const MachineFunction &Fn) const {
  const SIMachineFunctionInfo *Info = Fn.getInfo<SIMachineFunctionInfo>();
  if (Info->isEntryFunction()) {
    const MachineFrameInfo &MFI = Fn.getFrameInfo();
    return MFI.hasStackObjects() || MFI.hasCalls();
  }

  // May need scavenger for dealing with callee saved registers.
  return true;
}

bool SIRegisterInfo::requiresFrameIndexScavenging(
  const MachineFunction &MF) const {
  // Do not use frame virtual registers. They used to be used for SGPRs, but
  // once we reach PrologEpilogInserter, we can no longer spill SGPRs. If the
  // scavenger fails, we can increment/decrement the necessary SGPRs to avoid a
  // spill.
  return false;
}

bool SIRegisterInfo::requiresFrameIndexReplacementScavenging(
  const MachineFunction &MF) const {
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  return MFI.hasStackObjects();
}

bool SIRegisterInfo::requiresVirtualBaseRegisters(
  const MachineFunction &) const {
  // There are no special dedicated stack or frame pointers.
  return true;
}

bool SIRegisterInfo::trackLivenessAfterRegAlloc(const MachineFunction &MF) const {
  // This helps catch bugs as verifier errors.
  return true;
}

int64_t SIRegisterInfo::getMUBUFInstrOffset(const MachineInstr *MI) const {
  assert(SIInstrInfo::isMUBUF(*MI));

  int OffIdx = AMDGPU::getNamedOperandIdx(MI->getOpcode(),
                                          AMDGPU::OpName::offset);
  return MI->getOperand(OffIdx).getImm();
}

int64_t SIRegisterInfo::getFrameIndexInstrOffset(const MachineInstr *MI,
                                                 int Idx) const {
  if (!SIInstrInfo::isMUBUF(*MI))
    return 0;

  assert(Idx == AMDGPU::getNamedOperandIdx(MI->getOpcode(),
                                           AMDGPU::OpName::vaddr) &&
         "Should never see frame index on non-address operand");

  return getMUBUFInstrOffset(MI);
}

bool SIRegisterInfo::needsFrameBaseReg(MachineInstr *MI, int64_t Offset) const {
  if (!MI->mayLoadOrStore())
    return false;

  int64_t FullOffset = Offset + getMUBUFInstrOffset(MI);

  return !isUInt<12>(FullOffset);
}

void SIRegisterInfo::materializeFrameBaseRegister(MachineBasicBlock *MBB,
                                                  unsigned BaseReg,
                                                  int FrameIdx,
                                                  int64_t Offset) const {
  MachineBasicBlock::iterator Ins = MBB->begin();
  DebugLoc DL; // Defaults to "unknown"

  if (Ins != MBB->end())
    DL = Ins->getDebugLoc();

  MachineFunction *MF = MBB->getParent();
  const SIInstrInfo *TII = ST.getInstrInfo();

  if (Offset == 0) {
    BuildMI(*MBB, Ins, DL, TII->get(AMDGPU::V_MOV_B32_e32), BaseReg)
      .addFrameIndex(FrameIdx);
    return;
  }

  MachineRegisterInfo &MRI = MF->getRegInfo();
  Register OffsetReg = MRI.createVirtualRegister(&AMDGPU::SReg_32_XM0RegClass);

  Register FIReg = MRI.createVirtualRegister(&AMDGPU::VGPR_32RegClass);

  BuildMI(*MBB, Ins, DL, TII->get(AMDGPU::S_MOV_B32), OffsetReg)
    .addImm(Offset);
  BuildMI(*MBB, Ins, DL, TII->get(AMDGPU::V_MOV_B32_e32), FIReg)
    .addFrameIndex(FrameIdx);

  TII->getAddNoCarry(*MBB, Ins, DL, BaseReg)
    .addReg(OffsetReg, RegState::Kill)
    .addReg(FIReg)
    .addImm(0); // clamp bit
}

void SIRegisterInfo::resolveFrameIndex(MachineInstr &MI, unsigned BaseReg,
                                       int64_t Offset) const {
  const SIInstrInfo *TII = ST.getInstrInfo();

#ifndef NDEBUG
  // FIXME: Is it possible to be storing a frame index to itself?
  bool SeenFI = false;
  for (const MachineOperand &MO: MI.operands()) {
    if (MO.isFI()) {
      if (SeenFI)
        llvm_unreachable("should not see multiple frame indices");

      SeenFI = true;
    }
  }
#endif

  MachineOperand *FIOp = TII->getNamedOperand(MI, AMDGPU::OpName::vaddr);
#ifndef NDEBUG
  MachineBasicBlock *MBB = MI.getParent();
  MachineFunction *MF = MBB->getParent();
#endif
  assert(FIOp && FIOp->isFI() && "frame index must be address operand");
  assert(TII->isMUBUF(MI));
  assert(TII->getNamedOperand(MI, AMDGPU::OpName::soffset)->getReg() ==
         MF->getInfo<SIMachineFunctionInfo>()->getStackPtrOffsetReg() &&
         "should only be seeing stack pointer offset relative FrameIndex");

  MachineOperand *OffsetOp = TII->getNamedOperand(MI, AMDGPU::OpName::offset);
  int64_t NewOffset = OffsetOp->getImm() + Offset;
  assert(isUInt<12>(NewOffset) && "offset should be legal");

  FIOp->ChangeToRegister(BaseReg, false);
  OffsetOp->setImm(NewOffset);
}

bool SIRegisterInfo::isFrameOffsetLegal(const MachineInstr *MI,
                                        unsigned BaseReg,
                                        int64_t Offset) const {
  if (!SIInstrInfo::isMUBUF(*MI))
    return false;

  int64_t NewOffset = Offset + getMUBUFInstrOffset(MI);

  return isUInt<12>(NewOffset);
}

const TargetRegisterClass *SIRegisterInfo::getPointerRegClass(
  const MachineFunction &MF, unsigned Kind) const {
  // This is inaccurate. It depends on the instruction and address space. The
  // only place where we should hit this is for dealing with frame indexes /
  // private accesses, so this is correct in that case.
  return &AMDGPU::VGPR_32RegClass;
}

static unsigned getNumSubRegsForSpillOp(unsigned Op) {

  switch (Op) {
  case AMDGPU::SI_SPILL_S1024_SAVE:
  case AMDGPU::SI_SPILL_S1024_RESTORE:
  case AMDGPU::SI_SPILL_V1024_SAVE:
  case AMDGPU::SI_SPILL_V1024_RESTORE:
  case AMDGPU::SI_SPILL_A1024_SAVE:
  case AMDGPU::SI_SPILL_A1024_RESTORE:
    return 32;
  case AMDGPU::SI_SPILL_S512_SAVE:
  case AMDGPU::SI_SPILL_S512_RESTORE:
  case AMDGPU::SI_SPILL_V512_SAVE:
  case AMDGPU::SI_SPILL_V512_RESTORE:
  case AMDGPU::SI_SPILL_A512_SAVE:
  case AMDGPU::SI_SPILL_A512_RESTORE:
    return 16;
  case AMDGPU::SI_SPILL_S256_SAVE:
  case AMDGPU::SI_SPILL_S256_RESTORE:
  case AMDGPU::SI_SPILL_V256_SAVE:
  case AMDGPU::SI_SPILL_V256_RESTORE:
    return 8;
  case AMDGPU::SI_SPILL_S160_SAVE:
  case AMDGPU::SI_SPILL_S160_RESTORE:
  case AMDGPU::SI_SPILL_V160_SAVE:
  case AMDGPU::SI_SPILL_V160_RESTORE:
    return 5;
  case AMDGPU::SI_SPILL_S128_SAVE:
  case AMDGPU::SI_SPILL_S128_RESTORE:
  case AMDGPU::SI_SPILL_V128_SAVE:
  case AMDGPU::SI_SPILL_V128_RESTORE:
  case AMDGPU::SI_SPILL_A128_SAVE:
  case AMDGPU::SI_SPILL_A128_RESTORE:
    return 4;
  case AMDGPU::SI_SPILL_S96_SAVE:
  case AMDGPU::SI_SPILL_S96_RESTORE:
  case AMDGPU::SI_SPILL_V96_SAVE:
  case AMDGPU::SI_SPILL_V96_RESTORE:
    return 3;
  case AMDGPU::SI_SPILL_S64_SAVE:
  case AMDGPU::SI_SPILL_S64_RESTORE:
  case AMDGPU::SI_SPILL_V64_SAVE:
  case AMDGPU::SI_SPILL_V64_RESTORE:
  case AMDGPU::SI_SPILL_A64_SAVE:
  case AMDGPU::SI_SPILL_A64_RESTORE:
    return 2;
  case AMDGPU::SI_SPILL_S32_SAVE:
  case AMDGPU::SI_SPILL_S32_RESTORE:
  case AMDGPU::SI_SPILL_V32_SAVE:
  case AMDGPU::SI_SPILL_V32_RESTORE:
  case AMDGPU::SI_SPILL_A32_SAVE:
  case AMDGPU::SI_SPILL_A32_RESTORE:
    return 1;
  default: llvm_unreachable("Invalid spill opcode");
  }
}

static int getOffsetMUBUFStore(unsigned Opc) {
  switch (Opc) {
  case AMDGPU::BUFFER_STORE_DWORD_OFFEN:
    return AMDGPU::BUFFER_STORE_DWORD_OFFSET;
  case AMDGPU::BUFFER_STORE_BYTE_OFFEN:
    return AMDGPU::BUFFER_STORE_BYTE_OFFSET;
  case AMDGPU::BUFFER_STORE_SHORT_OFFEN:
    return AMDGPU::BUFFER_STORE_SHORT_OFFSET;
  case AMDGPU::BUFFER_STORE_DWORDX2_OFFEN:
    return AMDGPU::BUFFER_STORE_DWORDX2_OFFSET;
  case AMDGPU::BUFFER_STORE_DWORDX4_OFFEN:
    return AMDGPU::BUFFER_STORE_DWORDX4_OFFSET;
  case AMDGPU::BUFFER_STORE_SHORT_D16_HI_OFFEN:
    return AMDGPU::BUFFER_STORE_SHORT_D16_HI_OFFSET;
  case AMDGPU::BUFFER_STORE_BYTE_D16_HI_OFFEN:
    return AMDGPU::BUFFER_STORE_BYTE_D16_HI_OFFSET;
  default:
    return -1;
  }
}

static int getOffsetMUBUFLoad(unsigned Opc) {
  switch (Opc) {
  case AMDGPU::BUFFER_LOAD_DWORD_OFFEN:
    return AMDGPU::BUFFER_LOAD_DWORD_OFFSET;
  case AMDGPU::BUFFER_LOAD_UBYTE_OFFEN:
    return AMDGPU::BUFFER_LOAD_UBYTE_OFFSET;
  case AMDGPU::BUFFER_LOAD_SBYTE_OFFEN:
    return AMDGPU::BUFFER_LOAD_SBYTE_OFFSET;
  case AMDGPU::BUFFER_LOAD_USHORT_OFFEN:
    return AMDGPU::BUFFER_LOAD_USHORT_OFFSET;
  case AMDGPU::BUFFER_LOAD_SSHORT_OFFEN:
    return AMDGPU::BUFFER_LOAD_SSHORT_OFFSET;
  case AMDGPU::BUFFER_LOAD_DWORDX2_OFFEN:
    return AMDGPU::BUFFER_LOAD_DWORDX2_OFFSET;
  case AMDGPU::BUFFER_LOAD_DWORDX4_OFFEN:
    return AMDGPU::BUFFER_LOAD_DWORDX4_OFFSET;
  case AMDGPU::BUFFER_LOAD_UBYTE_D16_OFFEN:
    return AMDGPU::BUFFER_LOAD_UBYTE_D16_OFFSET;
  case AMDGPU::BUFFER_LOAD_UBYTE_D16_HI_OFFEN:
    return AMDGPU::BUFFER_LOAD_UBYTE_D16_HI_OFFSET;
  case AMDGPU::BUFFER_LOAD_SBYTE_D16_OFFEN:
    return AMDGPU::BUFFER_LOAD_SBYTE_D16_OFFSET;
  case AMDGPU::BUFFER_LOAD_SBYTE_D16_HI_OFFEN:
    return AMDGPU::BUFFER_LOAD_SBYTE_D16_HI_OFFSET;
  case AMDGPU::BUFFER_LOAD_SHORT_D16_OFFEN:
    return AMDGPU::BUFFER_LOAD_SHORT_D16_OFFSET;
  case AMDGPU::BUFFER_LOAD_SHORT_D16_HI_OFFEN:
    return AMDGPU::BUFFER_LOAD_SHORT_D16_HI_OFFSET;
  default:
    return -1;
  }
}

static MachineInstrBuilder spillVGPRtoAGPR(const GCNSubtarget &ST,
                                           MachineBasicBlock::iterator MI,
                                           int Index,
                                           unsigned Lane,
                                           unsigned ValueReg,
                                           bool IsKill) {
  MachineBasicBlock *MBB = MI->getParent();
  MachineFunction *MF = MI->getParent()->getParent();
  SIMachineFunctionInfo *MFI = MF->getInfo<SIMachineFunctionInfo>();
  const SIInstrInfo *TII = ST.getInstrInfo();

  MCPhysReg Reg = MFI->getVGPRToAGPRSpill(Index, Lane);

  if (Reg == AMDGPU::NoRegister)
    return MachineInstrBuilder();

  bool IsStore = MI->mayStore();
  MachineRegisterInfo &MRI = MF->getRegInfo();
  auto *TRI = static_cast<const SIRegisterInfo*>(MRI.getTargetRegisterInfo());

  unsigned Dst = IsStore ? Reg : ValueReg;
  unsigned Src = IsStore ? ValueReg : Reg;
  unsigned Opc = (IsStore ^ TRI->isVGPR(MRI, Reg)) ? AMDGPU::V_ACCVGPR_WRITE_B32
                                                   : AMDGPU::V_ACCVGPR_READ_B32;

  return BuildMI(*MBB, MI, MI->getDebugLoc(), TII->get(Opc), Dst)
           .addReg(Src, getKillRegState(IsKill));
}

// This differs from buildSpillLoadStore by only scavenging a VGPR. It does not
// need to handle the case where an SGPR may need to be spilled while spilling.
static bool buildMUBUFOffsetLoadStore(const GCNSubtarget &ST,
                                      MachineFrameInfo &MFI,
                                      MachineBasicBlock::iterator MI,
                                      int Index,
                                      int64_t Offset) {
  const SIInstrInfo *TII = ST.getInstrInfo();
  MachineBasicBlock *MBB = MI->getParent();
  const DebugLoc &DL = MI->getDebugLoc();
  bool IsStore = MI->mayStore();

  unsigned Opc = MI->getOpcode();
  int LoadStoreOp = IsStore ?
    getOffsetMUBUFStore(Opc) : getOffsetMUBUFLoad(Opc);
  if (LoadStoreOp == -1)
    return false;

  const MachineOperand *Reg = TII->getNamedOperand(*MI, AMDGPU::OpName::vdata);
  if (spillVGPRtoAGPR(ST, MI, Index, 0, Reg->getReg(), false).getInstr())
    return true;

  MachineInstrBuilder NewMI =
      BuildMI(*MBB, MI, DL, TII->get(LoadStoreOp))
          .add(*Reg)
          .add(*TII->getNamedOperand(*MI, AMDGPU::OpName::srsrc))
          .add(*TII->getNamedOperand(*MI, AMDGPU::OpName::soffset))
          .addImm(Offset)
          .addImm(0) // glc
          .addImm(0) // slc
          .addImm(0) // tfe
          .addImm(0) // dlc
          .addImm(0) // swz
          .cloneMemRefs(*MI);

  const MachineOperand *VDataIn = TII->getNamedOperand(*MI,
                                                       AMDGPU::OpName::vdata_in);
  if (VDataIn)
    NewMI.add(*VDataIn);
  return true;
}

void SIRegisterInfo::buildSpillLoadStore(MachineBasicBlock::iterator MI,
                                         unsigned LoadStoreOp,
                                         int Index,
                                         unsigned ValueReg,
                                         bool IsKill,
                                         unsigned ScratchRsrcReg,
                                         unsigned ScratchOffsetReg,
                                         int64_t InstOffset,
                                         MachineMemOperand *MMO,
                                         RegScavenger *RS) const {
  MachineBasicBlock *MBB = MI->getParent();
  MachineFunction *MF = MI->getParent()->getParent();
  const SIInstrInfo *TII = ST.getInstrInfo();
  const MachineFrameInfo &MFI = MF->getFrameInfo();

  const MCInstrDesc &Desc = TII->get(LoadStoreOp);
  const DebugLoc &DL = MI->getDebugLoc();
  bool IsStore = Desc.mayStore();

  bool Scavenged = false;
  unsigned SOffset = ScratchOffsetReg;

  const unsigned EltSize = 4;
  const TargetRegisterClass *RC = getRegClassForReg(MF->getRegInfo(), ValueReg);
  unsigned NumSubRegs = AMDGPU::getRegBitWidth(RC->getID()) / (EltSize * CHAR_BIT);
  unsigned Size = NumSubRegs * EltSize;
  int64_t Offset = InstOffset + MFI.getObjectOffset(Index);
  int64_t ScratchOffsetRegDelta = 0;

  unsigned Align = MFI.getObjectAlignment(Index);
  const MachinePointerInfo &BasePtrInfo = MMO->getPointerInfo();

  Register TmpReg =
    hasAGPRs(RC) ? TII->getNamedOperand(*MI, AMDGPU::OpName::tmp)->getReg()
                 : Register();

  assert((Offset % EltSize) == 0 && "unexpected VGPR spill offset");

  if (!isUInt<12>(Offset + Size - EltSize)) {
    SOffset = AMDGPU::NoRegister;

    // We currently only support spilling VGPRs to EltSize boundaries, meaning
    // we can simplify the adjustment of Offset here to just scale with
    // WavefrontSize.
    Offset *= ST.getWavefrontSize();

    // We don't have access to the register scavenger if this function is called
    // during  PEI::scavengeFrameVirtualRegs().
    if (RS)
      SOffset = RS->scavengeRegister(&AMDGPU::SGPR_32RegClass, MI, 0, false);

    if (SOffset == AMDGPU::NoRegister) {
      // There are no free SGPRs, and since we are in the process of spilling
      // VGPRs too.  Since we need a VGPR in order to spill SGPRs (this is true
      // on SI/CI and on VI it is true until we implement spilling using scalar
      // stores), we have no way to free up an SGPR.  Our solution here is to
      // add the offset directly to the ScratchOffset register, and then
      // subtract the offset after the spill to return ScratchOffset to it's
      // original value.
      SOffset = ScratchOffsetReg;
      ScratchOffsetRegDelta = Offset;
    } else {
      Scavenged = true;
    }

    BuildMI(*MBB, MI, DL, TII->get(AMDGPU::S_ADD_U32), SOffset)
      .addReg(ScratchOffsetReg)
      .addImm(Offset);

    Offset = 0;
  }

  for (unsigned i = 0, e = NumSubRegs; i != e; ++i, Offset += EltSize) {
    Register SubReg = NumSubRegs == 1
                          ? Register(ValueReg)
                          : getSubReg(ValueReg, getSubRegFromChannel(i));

    unsigned SOffsetRegState = 0;
    unsigned SrcDstRegState = getDefRegState(!IsStore);
    if (i + 1 == e) {
      SOffsetRegState |= getKillRegState(Scavenged);
      // The last implicit use carries the "Kill" flag.
      SrcDstRegState |= getKillRegState(IsKill);
    }

    auto MIB = spillVGPRtoAGPR(ST, MI, Index, i, SubReg, IsKill);

    if (!MIB.getInstr()) {
      unsigned FinalReg = SubReg;
      if (TmpReg != AMDGPU::NoRegister) {
        if (IsStore)
          BuildMI(*MBB, MI, DL, TII->get(AMDGPU::V_ACCVGPR_READ_B32), TmpReg)
            .addReg(SubReg, getKillRegState(IsKill));
        SubReg = TmpReg;
      }

      MachinePointerInfo PInfo = BasePtrInfo.getWithOffset(EltSize * i);
      MachineMemOperand *NewMMO
        = MF->getMachineMemOperand(PInfo, MMO->getFlags(),
                                   EltSize, MinAlign(Align, EltSize * i));

      MIB = BuildMI(*MBB, MI, DL, Desc)
        .addReg(SubReg, getDefRegState(!IsStore) | getKillRegState(IsKill))
        .addReg(ScratchRsrcReg)
        .addReg(SOffset, SOffsetRegState)
        .addImm(Offset)
        .addImm(0) // glc
        .addImm(0) // slc
        .addImm(0) // tfe
        .addImm(0) // dlc
        .addImm(0) // swz
        .addMemOperand(NewMMO);

      if (!IsStore && TmpReg != AMDGPU::NoRegister)
        MIB = BuildMI(*MBB, MI, DL, TII->get(AMDGPU::V_ACCVGPR_WRITE_B32),
                      FinalReg)
          .addReg(TmpReg, RegState::Kill);
    }

    if (NumSubRegs > 1)
      MIB.addReg(ValueReg, RegState::Implicit | SrcDstRegState);
  }

  if (ScratchOffsetRegDelta != 0) {
    // Subtract the offset we added to the ScratchOffset register.
    BuildMI(*MBB, MI, DL, TII->get(AMDGPU::S_SUB_U32), ScratchOffsetReg)
        .addReg(ScratchOffsetReg)
        .addImm(ScratchOffsetRegDelta);
  }
}

bool SIRegisterInfo::spillSGPR(MachineBasicBlock::iterator MI,
                               int Index,
                               RegScavenger *RS,
                               bool OnlyToVGPR) const {
  MachineBasicBlock *MBB = MI->getParent();
  MachineFunction *MF = MBB->getParent();
  SIMachineFunctionInfo *MFI = MF->getInfo<SIMachineFunctionInfo>();
  DenseSet<unsigned> SGPRSpillVGPRDefinedSet;

  ArrayRef<SIMachineFunctionInfo::SpilledReg> VGPRSpills
    = MFI->getSGPRToVGPRSpills(Index);
  bool SpillToVGPR = !VGPRSpills.empty();
  if (OnlyToVGPR && !SpillToVGPR)
    return false;

  const SIInstrInfo *TII = ST.getInstrInfo();

  Register SuperReg = MI->getOperand(0).getReg();
  bool IsKill = MI->getOperand(0).isKill();
  const DebugLoc &DL = MI->getDebugLoc();

  MachineFrameInfo &FrameInfo = MF->getFrameInfo();

  assert(SpillToVGPR || (SuperReg != MFI->getStackPtrOffsetReg() &&
                         SuperReg != MFI->getFrameOffsetReg() &&
                         SuperReg != MFI->getScratchWaveOffsetReg()));

  assert(SuperReg != AMDGPU::M0 && "m0 should never spill");

  unsigned EltSize = 4;
  const TargetRegisterClass *RC = getPhysRegClass(SuperReg);

  ArrayRef<int16_t> SplitParts = getRegSplitParts(RC, EltSize);
  unsigned NumSubRegs = SplitParts.empty() ? 1 : SplitParts.size();

  // Scavenged temporary VGPR to use. It must be scavenged once for any number
  // of spilled subregs.
  Register TmpVGPR;

  // SubReg carries the "Kill" flag when SubReg == SuperReg.
  unsigned SubKillState = getKillRegState((NumSubRegs == 1) && IsKill);
  for (unsigned i = 0, e = NumSubRegs; i < e; ++i) {
    Register SubReg =
        NumSubRegs == 1 ? SuperReg : getSubReg(SuperReg, SplitParts[i]);

    if (SpillToVGPR) {
      SIMachineFunctionInfo::SpilledReg Spill = VGPRSpills[i];

      // During SGPR spilling to VGPR, determine if the VGPR is defined. The
      // only circumstance in which we say it is undefined is when it is the
      // first spill to this VGPR in the first basic block.
      bool VGPRDefined = true;
      if (MBB == &MF->front())
        VGPRDefined = !SGPRSpillVGPRDefinedSet.insert(Spill.VGPR).second;

      // Mark the "old value of vgpr" input undef only if this is the first sgpr
      // spill to this specific vgpr in the first basic block.
      BuildMI(*MBB, MI, DL,
              TII->getMCOpcodeFromPseudo(AMDGPU::V_WRITELANE_B32),
              Spill.VGPR)
        .addReg(SubReg, getKillRegState(IsKill))
        .addImm(Spill.Lane)
        .addReg(Spill.VGPR, VGPRDefined ? 0 : RegState::Undef);

      // FIXME: Since this spills to another register instead of an actual
      // frame index, we should delete the frame index when all references to
      // it are fixed.
    } else {
      // XXX - Can to VGPR spill fail for some subregisters but not others?
      if (OnlyToVGPR)
        return false;

      // Spill SGPR to a frame index.
      if (!TmpVGPR.isValid())
        TmpVGPR = RS->scavengeRegister(&AMDGPU::VGPR_32RegClass, MI, 0);

      MachineInstrBuilder Mov
        = BuildMI(*MBB, MI, DL, TII->get(AMDGPU::V_MOV_B32_e32), TmpVGPR)
        .addReg(SubReg, SubKillState);

      // There could be undef components of a spilled super register.
      // TODO: Can we detect this and skip the spill?
      if (NumSubRegs > 1) {
        // The last implicit use of the SuperReg carries the "Kill" flag.
        unsigned SuperKillState = 0;
        if (i + 1 == e)
          SuperKillState |= getKillRegState(IsKill);
        Mov.addReg(SuperReg, RegState::Implicit | SuperKillState);
      }

      unsigned Align = FrameInfo.getObjectAlignment(Index);
      MachinePointerInfo PtrInfo
        = MachinePointerInfo::getFixedStack(*MF, Index, EltSize * i);
      MachineMemOperand *MMO
        = MF->getMachineMemOperand(PtrInfo, MachineMemOperand::MOStore,
                                   EltSize, MinAlign(Align, EltSize * i));
      BuildMI(*MBB, MI, DL, TII->get(AMDGPU::SI_SPILL_V32_SAVE))
        .addReg(TmpVGPR, RegState::Kill)      // src
        .addFrameIndex(Index)                 // vaddr
        .addReg(MFI->getScratchRSrcReg())     // srrsrc
        .addReg(MFI->getStackPtrOffsetReg())  // soffset
        .addImm(i * 4)                        // offset
        .addMemOperand(MMO);
    }
  }

  MI->eraseFromParent();
  MFI->addToSpilledSGPRs(NumSubRegs);
  return true;
}

bool SIRegisterInfo::restoreSGPR(MachineBasicBlock::iterator MI,
                                 int Index,
                                 RegScavenger *RS,
                                 bool OnlyToVGPR) const {
  MachineFunction *MF = MI->getParent()->getParent();
  MachineBasicBlock *MBB = MI->getParent();
  SIMachineFunctionInfo *MFI = MF->getInfo<SIMachineFunctionInfo>();

  ArrayRef<SIMachineFunctionInfo::SpilledReg> VGPRSpills
    = MFI->getSGPRToVGPRSpills(Index);
  bool SpillToVGPR = !VGPRSpills.empty();
  if (OnlyToVGPR && !SpillToVGPR)
    return false;

  MachineFrameInfo &FrameInfo = MF->getFrameInfo();
  const SIInstrInfo *TII = ST.getInstrInfo();
  const DebugLoc &DL = MI->getDebugLoc();

  Register SuperReg = MI->getOperand(0).getReg();

  assert(SuperReg != AMDGPU::M0 && "m0 should never spill");

  unsigned EltSize = 4;

  const TargetRegisterClass *RC = getPhysRegClass(SuperReg);

  ArrayRef<int16_t> SplitParts = getRegSplitParts(RC, EltSize);
  unsigned NumSubRegs = SplitParts.empty() ? 1 : SplitParts.size();

  Register TmpVGPR;

  for (unsigned i = 0, e = NumSubRegs; i < e; ++i) {
    Register SubReg =
        NumSubRegs == 1 ? SuperReg : getSubReg(SuperReg, SplitParts[i]);

    if (SpillToVGPR) {
      SIMachineFunctionInfo::SpilledReg Spill = VGPRSpills[i];
      auto MIB =
        BuildMI(*MBB, MI, DL, TII->getMCOpcodeFromPseudo(AMDGPU::V_READLANE_B32),
                SubReg)
        .addReg(Spill.VGPR)
        .addImm(Spill.Lane);

      if (NumSubRegs > 1 && i == 0)
        MIB.addReg(SuperReg, RegState::ImplicitDefine);
    } else {
      if (OnlyToVGPR)
        return false;

      // Restore SGPR from a stack slot.
      // FIXME: We should use S_LOAD_DWORD here for VI.
      if (!TmpVGPR.isValid())
        TmpVGPR = RS->scavengeRegister(&AMDGPU::VGPR_32RegClass, MI, 0);
      unsigned Align = FrameInfo.getObjectAlignment(Index);

      MachinePointerInfo PtrInfo
        = MachinePointerInfo::getFixedStack(*MF, Index, EltSize * i);

      MachineMemOperand *MMO = MF->getMachineMemOperand(PtrInfo,
        MachineMemOperand::MOLoad, EltSize,
        MinAlign(Align, EltSize * i));

      BuildMI(*MBB, MI, DL, TII->get(AMDGPU::SI_SPILL_V32_RESTORE), TmpVGPR)
        .addFrameIndex(Index)                 // vaddr
        .addReg(MFI->getScratchRSrcReg())     // srsrc
        .addReg(MFI->getStackPtrOffsetReg())  // soffset
        .addImm(i * 4)                        // offset
        .addMemOperand(MMO);

      auto MIB =
        BuildMI(*MBB, MI, DL, TII->get(AMDGPU::V_READFIRSTLANE_B32), SubReg)
        .addReg(TmpVGPR, RegState::Kill);

      if (NumSubRegs > 1)
        MIB.addReg(MI->getOperand(0).getReg(), RegState::ImplicitDefine);
    }
  }

  MI->eraseFromParent();
  return true;
}

/// Special case of eliminateFrameIndex. Returns true if the SGPR was spilled to
/// a VGPR and the stack slot can be safely eliminated when all other users are
/// handled.
bool SIRegisterInfo::eliminateSGPRToVGPRSpillFrameIndex(
  MachineBasicBlock::iterator MI,
  int FI,
  RegScavenger *RS) const {
  switch (MI->getOpcode()) {
  case AMDGPU::SI_SPILL_S1024_SAVE:
  case AMDGPU::SI_SPILL_S512_SAVE:
  case AMDGPU::SI_SPILL_S256_SAVE:
  case AMDGPU::SI_SPILL_S160_SAVE:
  case AMDGPU::SI_SPILL_S128_SAVE:
  case AMDGPU::SI_SPILL_S96_SAVE:
  case AMDGPU::SI_SPILL_S64_SAVE:
  case AMDGPU::SI_SPILL_S32_SAVE:
    return spillSGPR(MI, FI, RS, true);
  case AMDGPU::SI_SPILL_S1024_RESTORE:
  case AMDGPU::SI_SPILL_S512_RESTORE:
  case AMDGPU::SI_SPILL_S256_RESTORE:
  case AMDGPU::SI_SPILL_S160_RESTORE:
  case AMDGPU::SI_SPILL_S128_RESTORE:
  case AMDGPU::SI_SPILL_S96_RESTORE:
  case AMDGPU::SI_SPILL_S64_RESTORE:
  case AMDGPU::SI_SPILL_S32_RESTORE:
    return restoreSGPR(MI, FI, RS, true);
  default:
    llvm_unreachable("not an SGPR spill instruction");
  }
}

void SIRegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator MI,
                                        int SPAdj, unsigned FIOperandNum,
                                        RegScavenger *RS) const {
  MachineFunction *MF = MI->getParent()->getParent();
  MachineBasicBlock *MBB = MI->getParent();
  SIMachineFunctionInfo *MFI = MF->getInfo<SIMachineFunctionInfo>();
  MachineFrameInfo &FrameInfo = MF->getFrameInfo();
  const SIInstrInfo *TII = ST.getInstrInfo();
  DebugLoc DL = MI->getDebugLoc();

  assert(SPAdj == 0 && "unhandled SP adjustment in call sequence?");

  MachineOperand &FIOp = MI->getOperand(FIOperandNum);
  int Index = MI->getOperand(FIOperandNum).getIndex();

  Register FrameReg = getFrameRegister(*MF);

  switch (MI->getOpcode()) {
    // SGPR register spill
    case AMDGPU::SI_SPILL_S1024_SAVE:
    case AMDGPU::SI_SPILL_S512_SAVE:
    case AMDGPU::SI_SPILL_S256_SAVE:
    case AMDGPU::SI_SPILL_S160_SAVE:
    case AMDGPU::SI_SPILL_S128_SAVE:
    case AMDGPU::SI_SPILL_S96_SAVE:
    case AMDGPU::SI_SPILL_S64_SAVE:
    case AMDGPU::SI_SPILL_S32_SAVE: {
      spillSGPR(MI, Index, RS);
      break;
    }

    // SGPR register restore
    case AMDGPU::SI_SPILL_S1024_RESTORE:
    case AMDGPU::SI_SPILL_S512_RESTORE:
    case AMDGPU::SI_SPILL_S256_RESTORE:
    case AMDGPU::SI_SPILL_S160_RESTORE:
    case AMDGPU::SI_SPILL_S128_RESTORE:
    case AMDGPU::SI_SPILL_S96_RESTORE:
    case AMDGPU::SI_SPILL_S64_RESTORE:
    case AMDGPU::SI_SPILL_S32_RESTORE: {
      restoreSGPR(MI, Index, RS);
      break;
    }

    // VGPR register spill
    case AMDGPU::SI_SPILL_V1024_SAVE:
    case AMDGPU::SI_SPILL_V512_SAVE:
    case AMDGPU::SI_SPILL_V256_SAVE:
    case AMDGPU::SI_SPILL_V160_SAVE:
    case AMDGPU::SI_SPILL_V128_SAVE:
    case AMDGPU::SI_SPILL_V96_SAVE:
    case AMDGPU::SI_SPILL_V64_SAVE:
    case AMDGPU::SI_SPILL_V32_SAVE:
    case AMDGPU::SI_SPILL_A1024_SAVE:
    case AMDGPU::SI_SPILL_A512_SAVE:
    case AMDGPU::SI_SPILL_A128_SAVE:
    case AMDGPU::SI_SPILL_A64_SAVE:
    case AMDGPU::SI_SPILL_A32_SAVE: {
      const MachineOperand *VData = TII->getNamedOperand(*MI,
                                                         AMDGPU::OpName::vdata);
      assert(TII->getNamedOperand(*MI, AMDGPU::OpName::soffset)->getReg() ==
             MFI->getStackPtrOffsetReg());

      buildSpillLoadStore(MI, AMDGPU::BUFFER_STORE_DWORD_OFFSET,
            Index,
            VData->getReg(), VData->isKill(),
            TII->getNamedOperand(*MI, AMDGPU::OpName::srsrc)->getReg(),
            FrameReg,
            TII->getNamedOperand(*MI, AMDGPU::OpName::offset)->getImm(),
            *MI->memoperands_begin(),
            RS);
      MFI->addToSpilledVGPRs(getNumSubRegsForSpillOp(MI->getOpcode()));
      MI->eraseFromParent();
      break;
    }
    case AMDGPU::SI_SPILL_V32_RESTORE:
    case AMDGPU::SI_SPILL_V64_RESTORE:
    case AMDGPU::SI_SPILL_V96_RESTORE:
    case AMDGPU::SI_SPILL_V128_RESTORE:
    case AMDGPU::SI_SPILL_V160_RESTORE:
    case AMDGPU::SI_SPILL_V256_RESTORE:
    case AMDGPU::SI_SPILL_V512_RESTORE:
    case AMDGPU::SI_SPILL_V1024_RESTORE:
    case AMDGPU::SI_SPILL_A32_RESTORE:
    case AMDGPU::SI_SPILL_A64_RESTORE:
    case AMDGPU::SI_SPILL_A128_RESTORE:
    case AMDGPU::SI_SPILL_A512_RESTORE:
    case AMDGPU::SI_SPILL_A1024_RESTORE: {
      const MachineOperand *VData = TII->getNamedOperand(*MI,
                                                         AMDGPU::OpName::vdata);
      assert(TII->getNamedOperand(*MI, AMDGPU::OpName::soffset)->getReg() ==
             MFI->getStackPtrOffsetReg());

      buildSpillLoadStore(MI, AMDGPU::BUFFER_LOAD_DWORD_OFFSET,
            Index,
            VData->getReg(), VData->isKill(),
            TII->getNamedOperand(*MI, AMDGPU::OpName::srsrc)->getReg(),
            FrameReg,
            TII->getNamedOperand(*MI, AMDGPU::OpName::offset)->getImm(),
            *MI->memoperands_begin(),
            RS);
      MI->eraseFromParent();
      break;
    }

    default: {
      const DebugLoc &DL = MI->getDebugLoc();
      bool IsMUBUF = TII->isMUBUF(*MI);

      if (!IsMUBUF && !MFI->isEntryFunction()) {
        // Convert to an absolute stack address by finding the offset from the
        // scratch wave base and scaling by the wave size.
        //
        // In an entry function/kernel the offset is already the absolute
        // address relative to the frame register.

        Register TmpDiffReg =
          RS->scavengeRegister(&AMDGPU::SReg_32_XM0RegClass, MI, 0, false);

        // If there's no free SGPR, in-place modify the FP
        Register DiffReg = TmpDiffReg.isValid() ? TmpDiffReg : FrameReg;

        bool IsCopy = MI->getOpcode() == AMDGPU::V_MOV_B32_e32;
        Register ResultReg = IsCopy ?
          MI->getOperand(0).getReg() :
          RS->scavengeRegister(&AMDGPU::VGPR_32RegClass, MI, 0);

        BuildMI(*MBB, MI, DL, TII->get(AMDGPU::S_SUB_U32), DiffReg)
          .addReg(FrameReg)
          .addReg(MFI->getScratchWaveOffsetReg());

        int64_t Offset = FrameInfo.getObjectOffset(Index);
        if (Offset == 0) {
          // XXX - This never happens because of emergency scavenging slot at 0?
          BuildMI(*MBB, MI, DL, TII->get(AMDGPU::V_LSHRREV_B32_e64), ResultReg)
            .addImm(ST.getWavefrontSizeLog2())
            .addReg(DiffReg);
        } else {
          if (auto MIB = TII->getAddNoCarry(*MBB, MI, DL, ResultReg, *RS)) {
            Register ScaledReg =
              RS->scavengeRegister(&AMDGPU::VGPR_32RegClass, MIB, 0);

            BuildMI(*MBB, *MIB, DL, TII->get(AMDGPU::V_LSHRREV_B32_e64),
                    ScaledReg)
              .addImm(ST.getWavefrontSizeLog2())
              .addReg(DiffReg, RegState::Kill);

            const bool IsVOP2 = MIB->getOpcode() == AMDGPU::V_ADD_U32_e32;

            // TODO: Fold if use instruction is another add of a constant.
            if (IsVOP2 || AMDGPU::isInlinableLiteral32(Offset, ST.hasInv2PiInlineImm())) {
              // FIXME: This can fail
              MIB.addImm(Offset);
              MIB.addReg(ScaledReg, RegState::Kill);
              if (!IsVOP2)
                MIB.addImm(0); // clamp bit
            } else {
              assert(MIB->getOpcode() == AMDGPU::V_ADD_I32_e64 &&
                     "Need to reuse carry out register");

              // Use scavenged unused carry out as offset register.
              Register ConstOffsetReg;
              if (!isWave32)
                ConstOffsetReg = getSubReg(MIB.getReg(1), AMDGPU::sub0);
              else
                ConstOffsetReg = MIB.getReg(1);

              BuildMI(*MBB, *MIB, DL, TII->get(AMDGPU::S_MOV_B32), ConstOffsetReg)
                .addImm(Offset);
              MIB.addReg(ConstOffsetReg, RegState::Kill);
              MIB.addReg(ScaledReg, RegState::Kill);
              MIB.addImm(0); // clamp bit
            }
          } else {
            // We have to produce a carry out, and there isn't a free SGPR pair
            // for it. We can keep the whole computation on the SALU to avoid
            // clobbering an additional register at the cost of an extra mov.

            // We may have 1 free scratch SGPR even though a carry out is
            // unavailable. Only one additional mov is needed.
            Register TmpScaledReg =
                RS->scavengeRegister(&AMDGPU::SReg_32_XM0RegClass, MI, 0, false);
            Register ScaledReg = TmpScaledReg.isValid() ? TmpScaledReg : DiffReg;

            BuildMI(*MBB, MI, DL, TII->get(AMDGPU::S_LSHR_B32), ScaledReg)
              .addReg(DiffReg, RegState::Kill)
              .addImm(ST.getWavefrontSizeLog2());
            BuildMI(*MBB, MI, DL, TII->get(AMDGPU::S_ADD_U32), ScaledReg)
              .addReg(ScaledReg, RegState::Kill)
              .addImm(Offset);
            BuildMI(*MBB, MI, DL, TII->get(AMDGPU::COPY), ResultReg)
              .addReg(ScaledReg, RegState::Kill);

            // If there were truly no free SGPRs, we need to undo everything.
            if (!TmpScaledReg.isValid()) {
              BuildMI(*MBB, MI, DL, TII->get(AMDGPU::S_SUB_U32), ScaledReg)
                .addReg(ScaledReg, RegState::Kill)
                .addImm(Offset);
              BuildMI(*MBB, MI, DL, TII->get(AMDGPU::S_LSHL_B32), ScaledReg)
                .addReg(DiffReg, RegState::Kill)
                .addImm(ST.getWavefrontSizeLog2());
            }
          }
        }

        if (!TmpDiffReg.isValid()) {
          // Restore the FP.
          BuildMI(*MBB, MI, DL, TII->get(AMDGPU::S_ADD_U32), FrameReg)
            .addReg(FrameReg)
            .addReg(MFI->getScratchWaveOffsetReg());
        }

        // Don't introduce an extra copy if we're just materializing in a mov.
        if (IsCopy)
          MI->eraseFromParent();
        else
          FIOp.ChangeToRegister(ResultReg, false, false, true);
        return;
      }

      if (IsMUBUF) {
        // Disable offen so we don't need a 0 vgpr base.
        assert(static_cast<int>(FIOperandNum) ==
               AMDGPU::getNamedOperandIdx(MI->getOpcode(),
                                          AMDGPU::OpName::vaddr));

        assert(TII->getNamedOperand(*MI, AMDGPU::OpName::soffset)->getReg() ==
               MFI->getStackPtrOffsetReg());

        TII->getNamedOperand(*MI, AMDGPU::OpName::soffset)->setReg(FrameReg);

        int64_t Offset = FrameInfo.getObjectOffset(Index);
        int64_t OldImm
          = TII->getNamedOperand(*MI, AMDGPU::OpName::offset)->getImm();
        int64_t NewOffset = OldImm + Offset;

        if (isUInt<12>(NewOffset) &&
            buildMUBUFOffsetLoadStore(ST, FrameInfo, MI, Index, NewOffset)) {
          MI->eraseFromParent();
          return;
        }
      }

      // If the offset is simply too big, don't convert to a scratch wave offset
      // relative index.

      int64_t Offset = FrameInfo.getObjectOffset(Index);
      FIOp.ChangeToImmediate(Offset);
      if (!TII->isImmOperandLegal(*MI, FIOperandNum, FIOp)) {
        Register TmpReg = RS->scavengeRegister(&AMDGPU::VGPR_32RegClass, MI, 0);
        BuildMI(*MBB, MI, DL, TII->get(AMDGPU::V_MOV_B32_e32), TmpReg)
          .addImm(Offset);
        FIOp.ChangeToRegister(TmpReg, false, false, true);
      }
    }
  }
}

StringRef SIRegisterInfo::getRegAsmName(unsigned Reg) const {
  return AMDGPUInstPrinter::getRegisterName(Reg);
}

// FIXME: This is very slow. It might be worth creating a map from physreg to
// register class.
const TargetRegisterClass *SIRegisterInfo::getPhysRegClass(unsigned Reg) const {
  assert(!Register::isVirtualRegister(Reg));

  static const TargetRegisterClass *const BaseClasses[] = {
    &AMDGPU::VGPR_32RegClass,
    &AMDGPU::SReg_32RegClass,
    &AMDGPU::AGPR_32RegClass,
    &AMDGPU::VReg_64RegClass,
    &AMDGPU::SReg_64RegClass,
    &AMDGPU::AReg_64RegClass,
    &AMDGPU::VReg_96RegClass,
    &AMDGPU::SReg_96RegClass,
    &AMDGPU::VReg_128RegClass,
    &AMDGPU::SReg_128RegClass,
    &AMDGPU::AReg_128RegClass,
    &AMDGPU::VReg_160RegClass,
    &AMDGPU::SReg_160RegClass,
    &AMDGPU::VReg_256RegClass,
    &AMDGPU::SReg_256RegClass,
    &AMDGPU::VReg_512RegClass,
    &AMDGPU::SReg_512RegClass,
    &AMDGPU::AReg_512RegClass,
    &AMDGPU::SReg_1024RegClass,
    &AMDGPU::VReg_1024RegClass,
    &AMDGPU::AReg_1024RegClass,
    &AMDGPU::SCC_CLASSRegClass,
    &AMDGPU::Pseudo_SReg_32RegClass,
    &AMDGPU::Pseudo_SReg_128RegClass,
  };

  for (const TargetRegisterClass *BaseClass : BaseClasses) {
    if (BaseClass->contains(Reg)) {
      return BaseClass;
    }
  }
  return nullptr;
}

// TODO: It might be helpful to have some target specific flags in
// TargetRegisterClass to mark which classes are VGPRs to make this trivial.
bool SIRegisterInfo::hasVGPRs(const TargetRegisterClass *RC) const {
  unsigned Size = getRegSizeInBits(*RC);
  switch (Size) {
  case 32:
    return getCommonSubClass(&AMDGPU::VGPR_32RegClass, RC) != nullptr;
  case 64:
    return getCommonSubClass(&AMDGPU::VReg_64RegClass, RC) != nullptr;
  case 96:
    return getCommonSubClass(&AMDGPU::VReg_96RegClass, RC) != nullptr;
  case 128:
    return getCommonSubClass(&AMDGPU::VReg_128RegClass, RC) != nullptr;
  case 160:
    return getCommonSubClass(&AMDGPU::VReg_160RegClass, RC) != nullptr;
  case 256:
    return getCommonSubClass(&AMDGPU::VReg_256RegClass, RC) != nullptr;
  case 512:
    return getCommonSubClass(&AMDGPU::VReg_512RegClass, RC) != nullptr;
  case 1024:
    return getCommonSubClass(&AMDGPU::VReg_1024RegClass, RC) != nullptr;
  case 1:
    return getCommonSubClass(&AMDGPU::VReg_1RegClass, RC) != nullptr;
  default:
    assert(Size < 32 && "Invalid register class size");
    return false;
  }
}

bool SIRegisterInfo::hasAGPRs(const TargetRegisterClass *RC) const {
  unsigned Size = getRegSizeInBits(*RC);
  if (Size < 32)
    return false;
  switch (Size) {
  case 32:
    return getCommonSubClass(&AMDGPU::AGPR_32RegClass, RC) != nullptr;
  case 64:
    return getCommonSubClass(&AMDGPU::AReg_64RegClass, RC) != nullptr;
  case 96:
    return false;
  case 128:
    return getCommonSubClass(&AMDGPU::AReg_128RegClass, RC) != nullptr;
  case 160:
  case 256:
    return false;
  case 512:
    return getCommonSubClass(&AMDGPU::AReg_512RegClass, RC) != nullptr;
  case 1024:
    return getCommonSubClass(&AMDGPU::AReg_1024RegClass, RC) != nullptr;
  default:
    llvm_unreachable("Invalid register class size");
  }
}

const TargetRegisterClass *SIRegisterInfo::getEquivalentVGPRClass(
                                         const TargetRegisterClass *SRC) const {
  switch (getRegSizeInBits(*SRC)) {
  case 32:
    return &AMDGPU::VGPR_32RegClass;
  case 64:
    return &AMDGPU::VReg_64RegClass;
  case 96:
    return &AMDGPU::VReg_96RegClass;
  case 128:
    return &AMDGPU::VReg_128RegClass;
  case 160:
    return &AMDGPU::VReg_160RegClass;
  case 256:
    return &AMDGPU::VReg_256RegClass;
  case 512:
    return &AMDGPU::VReg_512RegClass;
  case 1024:
    return &AMDGPU::VReg_1024RegClass;
  case 1:
    return &AMDGPU::VReg_1RegClass;
  default:
    llvm_unreachable("Invalid register class size");
  }
}

const TargetRegisterClass *SIRegisterInfo::getEquivalentAGPRClass(
                                         const TargetRegisterClass *SRC) const {
  switch (getRegSizeInBits(*SRC)) {
  case 32:
    return &AMDGPU::AGPR_32RegClass;
  case 64:
    return &AMDGPU::AReg_64RegClass;
  case 128:
    return &AMDGPU::AReg_128RegClass;
  case 512:
    return &AMDGPU::AReg_512RegClass;
  case 1024:
    return &AMDGPU::AReg_1024RegClass;
  default:
    llvm_unreachable("Invalid register class size");
  }
}

const TargetRegisterClass *SIRegisterInfo::getEquivalentSGPRClass(
                                         const TargetRegisterClass *VRC) const {
  switch (getRegSizeInBits(*VRC)) {
  case 32:
    return &AMDGPU::SGPR_32RegClass;
  case 64:
    return &AMDGPU::SReg_64RegClass;
  case 96:
    return &AMDGPU::SReg_96RegClass;
  case 128:
    return &AMDGPU::SGPR_128RegClass;
  case 160:
    return &AMDGPU::SReg_160RegClass;
  case 256:
    return &AMDGPU::SReg_256RegClass;
  case 512:
    return &AMDGPU::SReg_512RegClass;
  case 1024:
    return &AMDGPU::SReg_1024RegClass;
  default:
    llvm_unreachable("Invalid register class size");
  }
}

const TargetRegisterClass *SIRegisterInfo::getSubRegClass(
                         const TargetRegisterClass *RC, unsigned SubIdx) const {
  if (SubIdx == AMDGPU::NoSubRegister)
    return RC;

  // We can assume that each lane corresponds to one 32-bit register.
  unsigned Count = getSubRegIndexLaneMask(SubIdx).getNumLanes();
  if (isSGPRClass(RC)) {
    switch (Count) {
    case 1:
      return &AMDGPU::SGPR_32RegClass;
    case 2:
      return &AMDGPU::SReg_64RegClass;
    case 3:
      return &AMDGPU::SReg_96RegClass;
    case 4:
      return &AMDGPU::SGPR_128RegClass;
    case 5:
      return &AMDGPU::SReg_160RegClass;
    case 8:
      return &AMDGPU::SReg_256RegClass;
    case 16:
      return &AMDGPU::SReg_512RegClass;
    case 32: /* fall-through */
    default:
      llvm_unreachable("Invalid sub-register class size");
    }
  } else if (hasAGPRs(RC)) {
    switch (Count) {
    case 1:
      return &AMDGPU::AGPR_32RegClass;
    case 2:
      return &AMDGPU::AReg_64RegClass;
    case 4:
      return &AMDGPU::AReg_128RegClass;
    case 16:
      return &AMDGPU::AReg_512RegClass;
    case 32: /* fall-through */
    default:
      llvm_unreachable("Invalid sub-register class size");
    }
  } else {
    switch (Count) {
    case 1:
      return &AMDGPU::VGPR_32RegClass;
    case 2:
      return &AMDGPU::VReg_64RegClass;
    case 3:
      return &AMDGPU::VReg_96RegClass;
    case 4:
      return &AMDGPU::VReg_128RegClass;
    case 5:
      return &AMDGPU::VReg_160RegClass;
    case 8:
      return &AMDGPU::VReg_256RegClass;
    case 16:
      return &AMDGPU::VReg_512RegClass;
    case 32: /* fall-through */
    default:
      llvm_unreachable("Invalid sub-register class size");
    }
  }
}

bool SIRegisterInfo::opCanUseInlineConstant(unsigned OpType) const {
  if (OpType >= AMDGPU::OPERAND_REG_INLINE_AC_FIRST &&
      OpType <= AMDGPU::OPERAND_REG_INLINE_AC_LAST)
    return !ST.hasMFMAInlineLiteralBug();

  return OpType >= AMDGPU::OPERAND_SRC_FIRST &&
         OpType <= AMDGPU::OPERAND_SRC_LAST;
}

bool SIRegisterInfo::shouldRewriteCopySrc(
  const TargetRegisterClass *DefRC,
  unsigned DefSubReg,
  const TargetRegisterClass *SrcRC,
  unsigned SrcSubReg) const {
  // We want to prefer the smallest register class possible, so we don't want to
  // stop and rewrite on anything that looks like a subregister
  // extract. Operations mostly don't care about the super register class, so we
  // only want to stop on the most basic of copies between the same register
  // class.
  //
  // e.g. if we have something like
  // %0 = ...
  // %1 = ...
  // %2 = REG_SEQUENCE %0, sub0, %1, sub1, %2, sub2
  // %3 = COPY %2, sub0
  //
  // We want to look through the COPY to find:
  //  => %3 = COPY %0

  // Plain copy.
  return getCommonSubClass(DefRC, SrcRC) != nullptr;
}

/// Returns a register that is not used at any point in the function.
///        If all registers are used, then this function will return
//         AMDGPU::NoRegister.
unsigned
SIRegisterInfo::findUnusedRegister(const MachineRegisterInfo &MRI,
                                   const TargetRegisterClass *RC,
                                   const MachineFunction &MF) const {

  for (unsigned Reg : *RC)
    if (MRI.isAllocatable(Reg) && !MRI.isPhysRegUsed(Reg))
      return Reg;
  return AMDGPU::NoRegister;
}

ArrayRef<int16_t> SIRegisterInfo::getRegSplitParts(const TargetRegisterClass *RC,
                                                   unsigned EltSize) const {
  if (EltSize == 4) {
    static const int16_t Sub0_31[] = {
      AMDGPU::sub0, AMDGPU::sub1, AMDGPU::sub2, AMDGPU::sub3,
      AMDGPU::sub4, AMDGPU::sub5, AMDGPU::sub6, AMDGPU::sub7,
      AMDGPU::sub8, AMDGPU::sub9, AMDGPU::sub10, AMDGPU::sub11,
      AMDGPU::sub12, AMDGPU::sub13, AMDGPU::sub14, AMDGPU::sub15,
      AMDGPU::sub16, AMDGPU::sub17, AMDGPU::sub18, AMDGPU::sub19,
      AMDGPU::sub20, AMDGPU::sub21, AMDGPU::sub22, AMDGPU::sub23,
      AMDGPU::sub24, AMDGPU::sub25, AMDGPU::sub26, AMDGPU::sub27,
      AMDGPU::sub28, AMDGPU::sub29, AMDGPU::sub30, AMDGPU::sub31,
    };

    static const int16_t Sub0_15[] = {
      AMDGPU::sub0, AMDGPU::sub1, AMDGPU::sub2, AMDGPU::sub3,
      AMDGPU::sub4, AMDGPU::sub5, AMDGPU::sub6, AMDGPU::sub7,
      AMDGPU::sub8, AMDGPU::sub9, AMDGPU::sub10, AMDGPU::sub11,
      AMDGPU::sub12, AMDGPU::sub13, AMDGPU::sub14, AMDGPU::sub15,
    };

    static const int16_t Sub0_7[] = {
      AMDGPU::sub0, AMDGPU::sub1, AMDGPU::sub2, AMDGPU::sub3,
      AMDGPU::sub4, AMDGPU::sub5, AMDGPU::sub6, AMDGPU::sub7,
    };

    static const int16_t Sub0_4[] = {
      AMDGPU::sub0, AMDGPU::sub1, AMDGPU::sub2, AMDGPU::sub3, AMDGPU::sub4,
    };

    static const int16_t Sub0_3[] = {
      AMDGPU::sub0, AMDGPU::sub1, AMDGPU::sub2, AMDGPU::sub3,
    };

    static const int16_t Sub0_2[] = {
      AMDGPU::sub0, AMDGPU::sub1, AMDGPU::sub2,
    };

    static const int16_t Sub0_1[] = {
      AMDGPU::sub0, AMDGPU::sub1,
    };

    switch (AMDGPU::getRegBitWidth(*RC->MC)) {
    case 32:
      return {};
    case 64:
      return makeArrayRef(Sub0_1);
    case 96:
      return makeArrayRef(Sub0_2);
    case 128:
      return makeArrayRef(Sub0_3);
    case 160:
      return makeArrayRef(Sub0_4);
    case 256:
      return makeArrayRef(Sub0_7);
    case 512:
      return makeArrayRef(Sub0_15);
    case 1024:
      return makeArrayRef(Sub0_31);
    default:
      llvm_unreachable("unhandled register size");
    }
  }

  if (EltSize == 8) {
    static const int16_t Sub0_31_64[] = {
      AMDGPU::sub0_sub1, AMDGPU::sub2_sub3,
      AMDGPU::sub4_sub5, AMDGPU::sub6_sub7,
      AMDGPU::sub8_sub9, AMDGPU::sub10_sub11,
      AMDGPU::sub12_sub13, AMDGPU::sub14_sub15,
      AMDGPU::sub16_sub17, AMDGPU::sub18_sub19,
      AMDGPU::sub20_sub21, AMDGPU::sub22_sub23,
      AMDGPU::sub24_sub25, AMDGPU::sub26_sub27,
      AMDGPU::sub28_sub29, AMDGPU::sub30_sub31
    };

    static const int16_t Sub0_15_64[] = {
      AMDGPU::sub0_sub1, AMDGPU::sub2_sub3,
      AMDGPU::sub4_sub5, AMDGPU::sub6_sub7,
      AMDGPU::sub8_sub9, AMDGPU::sub10_sub11,
      AMDGPU::sub12_sub13, AMDGPU::sub14_sub15
    };

    static const int16_t Sub0_7_64[] = {
      AMDGPU::sub0_sub1, AMDGPU::sub2_sub3,
      AMDGPU::sub4_sub5, AMDGPU::sub6_sub7
    };


    static const int16_t Sub0_3_64[] = {
      AMDGPU::sub0_sub1, AMDGPU::sub2_sub3
    };

    switch (AMDGPU::getRegBitWidth(*RC->MC)) {
    case 64:
      return {};
    case 128:
      return makeArrayRef(Sub0_3_64);
    case 256:
      return makeArrayRef(Sub0_7_64);
    case 512:
      return makeArrayRef(Sub0_15_64);
    case 1024:
      return makeArrayRef(Sub0_31_64);
    default:
      llvm_unreachable("unhandled register size");
    }
  }

  if (EltSize == 16) {

    static const int16_t Sub0_31_128[] = {
      AMDGPU::sub0_sub1_sub2_sub3,
      AMDGPU::sub4_sub5_sub6_sub7,
      AMDGPU::sub8_sub9_sub10_sub11,
      AMDGPU::sub12_sub13_sub14_sub15,
      AMDGPU::sub16_sub17_sub18_sub19,
      AMDGPU::sub20_sub21_sub22_sub23,
      AMDGPU::sub24_sub25_sub26_sub27,
      AMDGPU::sub28_sub29_sub30_sub31
    };

    static const int16_t Sub0_15_128[] = {
      AMDGPU::sub0_sub1_sub2_sub3,
      AMDGPU::sub4_sub5_sub6_sub7,
      AMDGPU::sub8_sub9_sub10_sub11,
      AMDGPU::sub12_sub13_sub14_sub15
    };

    static const int16_t Sub0_7_128[] = {
      AMDGPU::sub0_sub1_sub2_sub3,
      AMDGPU::sub4_sub5_sub6_sub7
    };

    switch (AMDGPU::getRegBitWidth(*RC->MC)) {
    case 128:
      return {};
    case 256:
      return makeArrayRef(Sub0_7_128);
    case 512:
      return makeArrayRef(Sub0_15_128);
    case 1024:
      return makeArrayRef(Sub0_31_128);
    default:
      llvm_unreachable("unhandled register size");
    }
  }

  assert(EltSize == 32 && "unhandled elt size");

  static const int16_t Sub0_31_256[] = {
    AMDGPU::sub0_sub1_sub2_sub3_sub4_sub5_sub6_sub7,
    AMDGPU::sub8_sub9_sub10_sub11_sub12_sub13_sub14_sub15,
    AMDGPU::sub16_sub17_sub18_sub19_sub20_sub21_sub22_sub23,
    AMDGPU::sub24_sub25_sub26_sub27_sub28_sub29_sub30_sub31
  };

  static const int16_t Sub0_15_256[] = {
    AMDGPU::sub0_sub1_sub2_sub3_sub4_sub5_sub6_sub7,
    AMDGPU::sub8_sub9_sub10_sub11_sub12_sub13_sub14_sub15
  };

  switch (AMDGPU::getRegBitWidth(*RC->MC)) {
  case 256:
    return {};
  case 512:
    return makeArrayRef(Sub0_15_256);
  case 1024:
    return makeArrayRef(Sub0_31_256);
  default:
    llvm_unreachable("unhandled register size");
  }
}

const TargetRegisterClass*
SIRegisterInfo::getRegClassForReg(const MachineRegisterInfo &MRI,
                                  unsigned Reg) const {
  if (Register::isVirtualRegister(Reg))
    return  MRI.getRegClass(Reg);

  return getPhysRegClass(Reg);
}

bool SIRegisterInfo::isVGPR(const MachineRegisterInfo &MRI,
                            unsigned Reg) const {
  const TargetRegisterClass * RC = getRegClassForReg(MRI, Reg);
  assert(RC && "Register class for the reg not found");
  return hasVGPRs(RC);
}

bool SIRegisterInfo::isAGPR(const MachineRegisterInfo &MRI,
                            unsigned Reg) const {
  const TargetRegisterClass * RC = getRegClassForReg(MRI, Reg);
  assert(RC && "Register class for the reg not found");
  return hasAGPRs(RC);
}

bool SIRegisterInfo::shouldCoalesce(MachineInstr *MI,
                                    const TargetRegisterClass *SrcRC,
                                    unsigned SubReg,
                                    const TargetRegisterClass *DstRC,
                                    unsigned DstSubReg,
                                    const TargetRegisterClass *NewRC,
                                    LiveIntervals &LIS) const {
  unsigned SrcSize = getRegSizeInBits(*SrcRC);
  unsigned DstSize = getRegSizeInBits(*DstRC);
  unsigned NewSize = getRegSizeInBits(*NewRC);

  // Do not increase size of registers beyond dword, we would need to allocate
  // adjacent registers and constraint regalloc more than needed.

  // Always allow dword coalescing.
  if (SrcSize <= 32 || DstSize <= 32)
    return true;

  return NewSize <= DstSize || NewSize <= SrcSize;
}

unsigned SIRegisterInfo::getRegPressureLimit(const TargetRegisterClass *RC,
                                             MachineFunction &MF) const {
  const SIMachineFunctionInfo *MFI = MF.getInfo<SIMachineFunctionInfo>();

  unsigned Occupancy = ST.getOccupancyWithLocalMemSize(MFI->getLDSSize(),
                                                       MF.getFunction());
  switch (RC->getID()) {
  default:
    return AMDGPURegisterInfo::getRegPressureLimit(RC, MF);
  case AMDGPU::VGPR_32RegClassID:
    return std::min(ST.getMaxNumVGPRs(Occupancy), ST.getMaxNumVGPRs(MF));
  case AMDGPU::SGPR_32RegClassID:
    return std::min(ST.getMaxNumSGPRs(Occupancy, true), ST.getMaxNumSGPRs(MF));
  }
}

unsigned SIRegisterInfo::getRegPressureSetLimit(const MachineFunction &MF,
                                                unsigned Idx) const {
  if (Idx == getVGPRPressureSet() || Idx == getAGPRPressureSet())
    return getRegPressureLimit(&AMDGPU::VGPR_32RegClass,
                               const_cast<MachineFunction &>(MF));

  if (Idx == getSGPRPressureSet())
    return getRegPressureLimit(&AMDGPU::SGPR_32RegClass,
                               const_cast<MachineFunction &>(MF));

  return AMDGPURegisterInfo::getRegPressureSetLimit(MF, Idx);
}

const int *SIRegisterInfo::getRegUnitPressureSets(unsigned RegUnit) const {
  static const int Empty[] = { -1 };

  if (hasRegUnit(AMDGPU::M0, RegUnit))
    return Empty;
  return AMDGPURegisterInfo::getRegUnitPressureSets(RegUnit);
}

unsigned SIRegisterInfo::getReturnAddressReg(const MachineFunction &MF) const {
  // Not a callee saved register.
  return AMDGPU::SGPR30_SGPR31;
}

const TargetRegisterClass *
SIRegisterInfo::getRegClassForSizeOnBank(unsigned Size,
                                         const RegisterBank &RB,
                                         const MachineRegisterInfo &MRI) const {
  switch (Size) {
  case 1: {
    switch (RB.getID()) {
    case AMDGPU::VGPRRegBankID:
      return &AMDGPU::VGPR_32RegClass;
    case AMDGPU::VCCRegBankID:
      return isWave32 ?
        &AMDGPU::SReg_32_XM0_XEXECRegClass : &AMDGPU::SReg_64_XEXECRegClass;
    case AMDGPU::SGPRRegBankID:
      return &AMDGPU::SReg_32RegClass;
    default:
      llvm_unreachable("unknown register bank");
    }
  }
  case 32:
    return RB.getID() == AMDGPU::VGPRRegBankID ? &AMDGPU::VGPR_32RegClass :
                                                 &AMDGPU::SReg_32RegClass;
  case 64:
    return RB.getID() == AMDGPU::VGPRRegBankID ? &AMDGPU::VReg_64RegClass :
                                                 &AMDGPU::SReg_64RegClass;
  case 96:
    return RB.getID() == AMDGPU::VGPRRegBankID ? &AMDGPU::VReg_96RegClass :
                                                 &AMDGPU::SReg_96RegClass;
  case 128:
    return RB.getID() == AMDGPU::VGPRRegBankID ? &AMDGPU::VReg_128RegClass :
                                                 &AMDGPU::SGPR_128RegClass;
  case 160:
    return RB.getID() == AMDGPU::VGPRRegBankID ? &AMDGPU::VReg_160RegClass :
                                                 &AMDGPU::SReg_160RegClass;
  case 256:
    return RB.getID() == AMDGPU::VGPRRegBankID ? &AMDGPU::VReg_256RegClass :
                                                 &AMDGPU::SReg_256RegClass;
  case 512:
    return RB.getID() == AMDGPU::VGPRRegBankID ? &AMDGPU::VReg_512RegClass :
                                                 &AMDGPU::SReg_512RegClass;
  case 1024:
    return RB.getID() == AMDGPU::VGPRRegBankID ? &AMDGPU::VReg_1024RegClass :
                                                 &AMDGPU::SReg_1024RegClass;
  default:
    if (Size < 32)
      return RB.getID() == AMDGPU::VGPRRegBankID ? &AMDGPU::VGPR_32RegClass :
                                                   &AMDGPU::SReg_32RegClass;
    return nullptr;
  }
}

const TargetRegisterClass *
SIRegisterInfo::getConstrainedRegClassForOperand(const MachineOperand &MO,
                                         const MachineRegisterInfo &MRI) const {
  const RegClassOrRegBank &RCOrRB = MRI.getRegClassOrRegBank(MO.getReg());
  if (const RegisterBank *RB = RCOrRB.dyn_cast<const RegisterBank*>())
    return getRegClassForTypeOnBank(MRI.getType(MO.getReg()), *RB, MRI);

  const TargetRegisterClass *RC = RCOrRB.get<const TargetRegisterClass*>();
  return getAllocatableClass(RC);
}

unsigned SIRegisterInfo::getVCC() const {
  return isWave32 ? AMDGPU::VCC_LO : AMDGPU::VCC;
}

const TargetRegisterClass *
SIRegisterInfo::getRegClass(unsigned RCID) const {
  switch ((int)RCID) {
  case AMDGPU::SReg_1RegClassID:
    return getBoolRC();
  case AMDGPU::SReg_1_XEXECRegClassID:
    return isWave32 ? &AMDGPU::SReg_32_XM0_XEXECRegClass
      : &AMDGPU::SReg_64_XEXECRegClass;
  case -1:
    return nullptr;
  default:
    return AMDGPURegisterInfo::getRegClass(RCID);
  }
}

// Find reaching register definition
MachineInstr *SIRegisterInfo::findReachingDef(unsigned Reg, unsigned SubReg,
                                              MachineInstr &Use,
                                              MachineRegisterInfo &MRI,
                                              LiveIntervals *LIS) const {
  auto &MDT = LIS->getAnalysis<MachineDominatorTree>();
  SlotIndex UseIdx = LIS->getInstructionIndex(Use);
  SlotIndex DefIdx;

  if (Register::isVirtualRegister(Reg)) {
    if (!LIS->hasInterval(Reg))
      return nullptr;
    LiveInterval &LI = LIS->getInterval(Reg);
    LaneBitmask SubLanes = SubReg ? getSubRegIndexLaneMask(SubReg)
                                  : MRI.getMaxLaneMaskForVReg(Reg);
    VNInfo *V = nullptr;
    if (LI.hasSubRanges()) {
      for (auto &S : LI.subranges()) {
        if ((S.LaneMask & SubLanes) == SubLanes) {
          V = S.getVNInfoAt(UseIdx);
          break;
        }
      }
    } else {
      V = LI.getVNInfoAt(UseIdx);
    }
    if (!V)
      return nullptr;
    DefIdx = V->def;
  } else {
    // Find last def.
    for (MCRegUnitIterator Units(Reg, this); Units.isValid(); ++Units) {
      LiveRange &LR = LIS->getRegUnit(*Units);
      if (VNInfo *V = LR.getVNInfoAt(UseIdx)) {
        if (!DefIdx.isValid() ||
            MDT.dominates(LIS->getInstructionFromIndex(DefIdx),
                          LIS->getInstructionFromIndex(V->def)))
          DefIdx = V->def;
      } else {
        return nullptr;
      }
    }
  }

  MachineInstr *Def = LIS->getInstructionFromIndex(DefIdx);

  if (!Def || !MDT.dominates(Def, &Use))
    return nullptr;

  assert(Def->modifiesRegister(Reg, this));

  return Def;
}

int16_t SIRegisterInfo::calcSubRegIdx(const TargetRegisterClass *RC, unsigned SubOffset) const {
  static const int16_t DwordSub[] = {
    AMDGPU::sub0, AMDGPU::sub1, AMDGPU::sub2, AMDGPU::sub3,
    AMDGPU::sub4, AMDGPU::sub5, AMDGPU::sub6, AMDGPU::sub7,
    AMDGPU::sub8, AMDGPU::sub9, AMDGPU::sub10, AMDGPU::sub11,
    AMDGPU::sub12, AMDGPU::sub13, AMDGPU::sub14, AMDGPU::sub15
  };
  static const int16_t Dword2Sub[] = {
    AMDGPU::sub0_sub1, AMDGPU::sub1_sub2,
    AMDGPU::sub2_sub3, AMDGPU::sub3_sub4,
    AMDGPU::sub4_sub5, AMDGPU::sub5_sub6,
    AMDGPU::sub6_sub7, AMDGPU::sub7_sub8,
    AMDGPU::sub8_sub9, AMDGPU::sub9_sub10,
    AMDGPU::sub10_sub11, AMDGPU::sub11_sub12,
    AMDGPU::sub12_sub13, AMDGPU::sub13_sub14,
    AMDGPU::sub14_sub15
  };
  static const int16_t Dword4Sub[] = { AMDGPU::sub0_sub1_sub2_sub3,
    AMDGPU::sub1_sub2_sub3_sub4,
    AMDGPU::sub2_sub3_sub4_sub5,
    AMDGPU::sub3_sub4_sub5_sub6,
    AMDGPU::sub4_sub5_sub6_sub7,
    AMDGPU::sub5_sub6_sub7_sub8,
    AMDGPU::sub6_sub7_sub8_sub9,
    AMDGPU::sub7_sub8_sub9_sub10,
    AMDGPU::sub8_sub9_sub10_sub11,
    AMDGPU::sub9_sub10_sub11_sub12,
    AMDGPU::sub10_sub11_sub12_sub13,
    AMDGPU::sub11_sub12_sub13_sub14,
    AMDGPU::sub12_sub13_sub14_sub15
  };
  static const int16_t Dword8Sub[] = {
    AMDGPU::sub0_sub1_sub2_sub3_sub4_sub5_sub6_sub7,
    AMDGPU::sub1_sub2_sub3_sub4_sub5_sub6_sub7_sub8,
    AMDGPU::sub2_sub3_sub4_sub5_sub6_sub7_sub8_sub9,
    AMDGPU::sub3_sub4_sub5_sub6_sub7_sub8_sub9_sub10,
    AMDGPU::sub4_sub5_sub6_sub7_sub8_sub9_sub10_sub11,
    AMDGPU::sub5_sub6_sub7_sub8_sub9_sub10_sub11_sub12,
    AMDGPU::sub6_sub7_sub8_sub9_sub10_sub11_sub12_sub13,
    AMDGPU::sub7_sub8_sub9_sub10_sub11_sub12_sub13_sub14,
    AMDGPU::sub8_sub9_sub10_sub11_sub12_sub13_sub14_sub15
  };
  
  // Get the size of the instruction we're replacing
  unsigned SubSize = getRegSizeInBits(*RC) / 32;
  switch(SubSize) {
    default:
      llvm_unreachable_internal();
      break;
    case 8:
      return Dword8Sub[SubOffset];
      break;
    case 4:
      return Dword4Sub[SubOffset];
      break;
    case 2:
      return Dword2Sub[SubOffset];
      break;
    case 1:
      return DwordSub[SubOffset];
      break;
  }
}

