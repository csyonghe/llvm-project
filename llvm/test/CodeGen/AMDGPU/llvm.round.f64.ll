; Modifications Copyright (c) 2019 Advanced Micro Devices, Inc. All rights reserved.
; Notified per clause 4(b) of the license.
; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -march=amdgcn -mcpu=tahiti < %s | FileCheck -check-prefix=SI %s
; RUN: llc -march=amdgcn -mcpu=hawaii < %s | FileCheck -check-prefix=CI %s

define amdgpu_kernel void @round_f64(double addrspace(1)* %out, double %x) #0 {
; SI-LABEL: round_f64:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx4 s[0:3], s[0:1], 0x9
; SI-NEXT:    s_mov_b32 s6, -1
; SI-NEXT:    s_mov_b32 s11, 0x80000
; SI-NEXT:    s_mov_b32 s10, 0
; SI-NEXT:    s_mov_b32 s7, 0xf000
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_mov_b32 s4, s0
; SI-NEXT:    s_bfe_u32 s0, s3, 0xb0014
; SI-NEXT:    s_add_i32 s12, s0, 0xfffffc01
; SI-NEXT:    s_mov_b32 s5, s1
; SI-NEXT:    s_mov_b32 s1, 0xfffff
; SI-NEXT:    s_mov_b32 s0, s6
; SI-NEXT:    s_lshr_b64 s[0:1], s[0:1], s12
; SI-NEXT:    s_and_b64 s[8:9], s[2:3], s[0:1]
; SI-NEXT:    s_lshr_b64 s[10:11], s[10:11], s12
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[8:9], 0
; SI-NEXT:    v_mov_b32_e32 v1, s10
; SI-NEXT:    v_mov_b32_e32 v0, s11
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v1, vcc
; SI-NEXT:    v_cndmask_b32_e32 v0, 0, v0, vcc
; SI-NEXT:    v_mov_b32_e32 v2, s3
; SI-NEXT:    v_add_i32_e32 v1, vcc, s2, v1
; SI-NEXT:    v_addc_u32_e32 v0, vcc, v2, v0, vcc
; SI-NEXT:    v_not_b32_e32 v2, s0
; SI-NEXT:    v_and_b32_e32 v2, v1, v2
; SI-NEXT:    v_not_b32_e32 v1, s1
; SI-NEXT:    v_and_b32_e32 v0, v0, v1
; SI-NEXT:    v_mov_b32_e32 v1, 0x3ff00000
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s12, -1
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v1, vcc
; SI-NEXT:    s_brev_b32 s0, -2
; SI-NEXT:    v_mov_b32_e32 v3, s3
; SI-NEXT:    v_bfi_b32 v1, s0, v1, v3
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s12, 0
; SI-NEXT:    v_cndmask_b32_e32 v0, v0, v1, vcc
; SI-NEXT:    v_mov_b32_e32 v1, s3
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s12, 51
; SI-NEXT:    v_cndmask_b32_e64 v1, v0, v1, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v0, v2, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v2, s2
; SI-NEXT:    v_cndmask_b32_e64 v0, v0, v2, s[0:1]
; SI-NEXT:    buffer_store_dwordx2 v[0:1], off, s[4:7], 0
; SI-NEXT:    s_endpgm
;
; CI-LABEL: round_f64:
; CI:       ; %bb.0:
; CI-NEXT:    s_load_dwordx4 s[4:7], s[0:1], 0x9
; CI-NEXT:    s_brev_b32 s8, -2
; CI-NEXT:    v_mov_b32_e32 v4, 0x3ff00000
; CI-NEXT:    s_mov_b32 s3, 0xf000
; CI-NEXT:    s_mov_b32 s2, -1
; CI-NEXT:    s_waitcnt lgkmcnt(0)
; CI-NEXT:    v_trunc_f64_e32 v[0:1], s[6:7]
; CI-NEXT:    v_mov_b32_e32 v5, s7
; CI-NEXT:    v_add_f64 v[2:3], s[6:7], -v[0:1]
; CI-NEXT:    v_bfi_b32 v4, s8, v4, v5
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[2:3]|, 0.5
; CI-NEXT:    v_mov_b32_e32 v2, 0
; CI-NEXT:    v_cndmask_b32_e32 v3, 0, v4, vcc
; CI-NEXT:    v_add_f64 v[0:1], v[0:1], v[2:3]
; CI-NEXT:    s_mov_b32 s0, s4
; CI-NEXT:    s_mov_b32 s1, s5
; CI-NEXT:    buffer_store_dwordx2 v[0:1], off, s[0:3], 0
; CI-NEXT:    s_endpgm
  %result = call double @llvm.round.f64(double %x) #1
  store double %result, double addrspace(1)* %out
  ret void
}

define amdgpu_kernel void @v_round_f64(double addrspace(1)* %out, double addrspace(1)* %in) #0 {
; SI-LABEL: v_round_f64:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx4 s[4:7], s[0:1], 0x9
; SI-NEXT:    s_mov_b32 s3, 0xf000
; SI-NEXT:    s_mov_b32 s2, 0
; SI-NEXT:    v_lshlrev_b32_e32 v0, 3, v0
; SI-NEXT:    v_mov_b32_e32 v1, 0
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_mov_b64 s[0:1], s[6:7]
; SI-NEXT:    buffer_load_dwordx2 v[2:3], v[0:1], s[0:3], 0 addr64
; SI-NEXT:    s_movk_i32 s11, 0xfc01
; SI-NEXT:    s_mov_b32 s9, 0xfffff
; SI-NEXT:    s_mov_b32 s8, -1
; SI-NEXT:    v_mov_b32_e32 v8, 0x3ff00000
; SI-NEXT:    s_brev_b32 s10, -2
; SI-NEXT:    s_mov_b64 s[6:7], s[2:3]
; SI-NEXT:    s_mov_b32 s3, 0x80000
; SI-NEXT:    s_waitcnt vmcnt(0)
; SI-NEXT:    v_bfe_u32 v4, v3, 20, 11
; SI-NEXT:    v_add_i32_e32 v10, vcc, s11, v4
; SI-NEXT:    v_lshr_b64 v[4:5], s[8:9], v10
; SI-NEXT:    v_cmp_eq_u32_e32 vcc, -1, v10
; SI-NEXT:    v_cndmask_b32_e32 v8, 0, v8, vcc
; SI-NEXT:    v_bfi_b32 v11, s10, v8, v3
; SI-NEXT:    v_and_b32_e32 v9, v3, v5
; SI-NEXT:    v_and_b32_e32 v8, v2, v4
; SI-NEXT:    v_lshr_b64 v[6:7], s[2:3], v10
; SI-NEXT:    v_cmp_ne_u64_e32 vcc, 0, v[8:9]
; SI-NEXT:    v_not_b32_e32 v4, v4
; SI-NEXT:    v_cndmask_b32_e32 v6, 0, v6, vcc
; SI-NEXT:    v_cndmask_b32_e32 v7, 0, v7, vcc
; SI-NEXT:    v_add_i32_e32 v6, vcc, v2, v6
; SI-NEXT:    v_addc_u32_e32 v7, vcc, v3, v7, vcc
; SI-NEXT:    v_not_b32_e32 v5, v5
; SI-NEXT:    v_and_b32_e32 v5, v7, v5
; SI-NEXT:    v_cmp_gt_i32_e32 vcc, 0, v10
; SI-NEXT:    v_and_b32_e32 v4, v6, v4
; SI-NEXT:    v_cndmask_b32_e32 v5, v5, v11, vcc
; SI-NEXT:    v_cndmask_b32_e64 v4, v4, 0, vcc
; SI-NEXT:    v_cmp_lt_i32_e32 vcc, 51, v10
; SI-NEXT:    v_cndmask_b32_e32 v3, v5, v3, vcc
; SI-NEXT:    v_cndmask_b32_e32 v2, v4, v2, vcc
; SI-NEXT:    buffer_store_dwordx2 v[2:3], v[0:1], s[4:7], 0 addr64
; SI-NEXT:    s_endpgm
;
; CI-LABEL: v_round_f64:
; CI:       ; %bb.0:
; CI-NEXT:    s_load_dwordx4 s[4:7], s[0:1], 0x9
; CI-NEXT:    s_mov_b32 s3, 0xf000
; CI-NEXT:    s_mov_b32 s2, 0
; CI-NEXT:    v_lshlrev_b32_e32 v0, 3, v0
; CI-NEXT:    v_mov_b32_e32 v1, 0
; CI-NEXT:    s_waitcnt lgkmcnt(0)
; CI-NEXT:    s_mov_b64 s[0:1], s[6:7]
; CI-NEXT:    buffer_load_dwordx2 v[2:3], v[0:1], s[0:3], 0 addr64
; CI-NEXT:    s_brev_b32 s6, -2
; CI-NEXT:    v_mov_b32_e32 v8, 0x3ff00000
; CI-NEXT:    s_waitcnt vmcnt(0)
; CI-NEXT:    v_trunc_f64_e32 v[4:5], v[2:3]
; CI-NEXT:    v_add_f64 v[6:7], v[2:3], -v[4:5]
; CI-NEXT:    v_bfi_b32 v2, s6, v8, v3
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[6:7]|, 0.5
; CI-NEXT:    s_mov_b64 s[6:7], s[2:3]
; CI-NEXT:    v_cndmask_b32_e32 v3, 0, v2, vcc
; CI-NEXT:    v_mov_b32_e32 v2, 0
; CI-NEXT:    v_add_f64 v[2:3], v[4:5], v[2:3]
; CI-NEXT:    buffer_store_dwordx2 v[2:3], v[0:1], s[4:7], 0 addr64
; CI-NEXT:    s_endpgm
  %tid = call i32 @llvm.amdgcn.workitem.id.x() #1
  %gep = getelementptr double, double addrspace(1)* %in, i32 %tid
  %out.gep = getelementptr double, double addrspace(1)* %out, i32 %tid
  %x = load double, double addrspace(1)* %gep
  %result = call double @llvm.round.f64(double %x) #1
  store double %result, double addrspace(1)* %out.gep
  ret void
}

define amdgpu_kernel void @round_v2f64(<2 x double> addrspace(1)* %out, <2 x double> %in) #0 {
; SI-LABEL: round_v2f64:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x9
; SI-NEXT:    s_load_dwordx4 s[8:11], s[0:1], 0xd
; SI-NEXT:    s_mov_b32 s6, -1
; SI-NEXT:    s_movk_i32 s18, 0xfc01
; SI-NEXT:    s_mov_b32 s3, 0xfffff
; SI-NEXT:    s_mov_b32 s2, s6
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_bfe_u32 s0, s11, 0xb0014
; SI-NEXT:    s_add_i32 s19, s0, s18
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s19
; SI-NEXT:    s_and_b64 s[12:13], s[10:11], s[0:1]
; SI-NEXT:    s_mov_b32 s15, 0x80000
; SI-NEXT:    s_mov_b32 s14, 0
; SI-NEXT:    s_lshr_b64 s[16:17], s[14:15], s19
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[12:13], 0
; SI-NEXT:    v_mov_b32_e32 v1, s16
; SI-NEXT:    v_mov_b32_e32 v0, s17
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v1, vcc
; SI-NEXT:    v_cndmask_b32_e32 v0, 0, v0, vcc
; SI-NEXT:    v_mov_b32_e32 v2, s11
; SI-NEXT:    v_add_i32_e32 v1, vcc, s10, v1
; SI-NEXT:    v_addc_u32_e32 v0, vcc, v2, v0, vcc
; SI-NEXT:    v_not_b32_e32 v2, s0
; SI-NEXT:    v_and_b32_e32 v1, v1, v2
; SI-NEXT:    v_not_b32_e32 v2, s1
; SI-NEXT:    v_mov_b32_e32 v4, 0x3ff00000
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s19, -1
; SI-NEXT:    v_and_b32_e32 v0, v0, v2
; SI-NEXT:    v_cndmask_b32_e32 v2, 0, v4, vcc
; SI-NEXT:    s_brev_b32 s12, -2
; SI-NEXT:    v_mov_b32_e32 v3, s11
; SI-NEXT:    v_bfi_b32 v2, s12, v2, v3
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s19, 0
; SI-NEXT:    v_cndmask_b32_e32 v0, v0, v2, vcc
; SI-NEXT:    v_mov_b32_e32 v2, s11
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s19, 51
; SI-NEXT:    v_cndmask_b32_e64 v3, v0, v2, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v0, v1, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v1, s10
; SI-NEXT:    v_cndmask_b32_e64 v2, v0, v1, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s9, 0xb0014
; SI-NEXT:    s_add_i32 s13, s0, s18
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s13
; SI-NEXT:    s_and_b64 s[2:3], s[8:9], s[0:1]
; SI-NEXT:    s_lshr_b64 s[10:11], s[14:15], s13
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[2:3], 0
; SI-NEXT:    v_mov_b32_e32 v1, s10
; SI-NEXT:    v_mov_b32_e32 v0, s11
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v1, vcc
; SI-NEXT:    v_cndmask_b32_e32 v0, 0, v0, vcc
; SI-NEXT:    v_mov_b32_e32 v5, s9
; SI-NEXT:    v_add_i32_e32 v1, vcc, s8, v1
; SI-NEXT:    v_addc_u32_e32 v0, vcc, v5, v0, vcc
; SI-NEXT:    v_not_b32_e32 v5, s0
; SI-NEXT:    v_and_b32_e32 v5, v1, v5
; SI-NEXT:    v_not_b32_e32 v1, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s13, -1
; SI-NEXT:    v_and_b32_e32 v0, v0, v1
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v4, vcc
; SI-NEXT:    v_mov_b32_e32 v4, s9
; SI-NEXT:    v_bfi_b32 v1, s12, v1, v4
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s13, 0
; SI-NEXT:    v_cndmask_b32_e32 v0, v0, v1, vcc
; SI-NEXT:    v_mov_b32_e32 v1, s9
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s13, 51
; SI-NEXT:    v_cndmask_b32_e64 v1, v0, v1, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v0, v5, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v4, s8
; SI-NEXT:    s_mov_b32 s7, 0xf000
; SI-NEXT:    v_cndmask_b32_e64 v0, v0, v4, s[0:1]
; SI-NEXT:    buffer_store_dwordx4 v[0:3], off, s[4:7], 0
; SI-NEXT:    s_endpgm
;
; CI-LABEL: round_v2f64:
; CI:       ; %bb.0:
; CI-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x9
; CI-NEXT:    s_load_dwordx4 s[0:3], s[0:1], 0xd
; CI-NEXT:    s_brev_b32 s6, -2
; CI-NEXT:    v_mov_b32_e32 v6, 0x3ff00000
; CI-NEXT:    s_mov_b32 s7, 0xf000
; CI-NEXT:    s_waitcnt lgkmcnt(0)
; CI-NEXT:    v_trunc_f64_e32 v[0:1], s[2:3]
; CI-NEXT:    v_mov_b32_e32 v4, s3
; CI-NEXT:    v_add_f64 v[2:3], s[2:3], -v[0:1]
; CI-NEXT:    v_bfi_b32 v4, s6, v6, v4
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[2:3]|, 0.5
; CI-NEXT:    v_mov_b32_e32 v2, 0
; CI-NEXT:    v_cndmask_b32_e32 v3, 0, v4, vcc
; CI-NEXT:    v_trunc_f64_e32 v[4:5], s[0:1]
; CI-NEXT:    v_add_f64 v[2:3], v[0:1], v[2:3]
; CI-NEXT:    v_add_f64 v[0:1], s[0:1], -v[4:5]
; CI-NEXT:    v_mov_b32_e32 v7, s1
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[0:1]|, 0.5
; CI-NEXT:    v_bfi_b32 v6, s6, v6, v7
; CI-NEXT:    v_cndmask_b32_e32 v1, 0, v6, vcc
; CI-NEXT:    v_mov_b32_e32 v0, 0
; CI-NEXT:    v_add_f64 v[0:1], v[4:5], v[0:1]
; CI-NEXT:    s_mov_b32 s6, -1
; CI-NEXT:    buffer_store_dwordx4 v[0:3], off, s[4:7], 0
; CI-NEXT:    s_endpgm
  %result = call <2 x double> @llvm.round.v2f64(<2 x double> %in) #1
  store <2 x double> %result, <2 x double> addrspace(1)* %out
  ret void
}

define amdgpu_kernel void @round_v4f64(<4 x double> addrspace(1)* %out, <4 x double> %in) #0 {
; SI-LABEL: round_v4f64:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x9
; SI-NEXT:    s_load_dwordx8 s[8:15], s[0:1], 0x11
; SI-NEXT:    s_mov_b32 s6, -1
; SI-NEXT:    s_movk_i32 s22, 0xfc01
; SI-NEXT:    s_mov_b32 s3, 0xfffff
; SI-NEXT:    s_mov_b32 s2, s6
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_bfe_u32 s0, s11, 0xb0014
; SI-NEXT:    s_add_i32 s23, s0, s22
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s23
; SI-NEXT:    s_and_b64 s[16:17], s[10:11], s[0:1]
; SI-NEXT:    s_mov_b32 s19, 0x80000
; SI-NEXT:    s_mov_b32 s18, 0
; SI-NEXT:    s_lshr_b64 s[20:21], s[18:19], s23
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[16:17], 0
; SI-NEXT:    v_mov_b32_e32 v1, s20
; SI-NEXT:    v_mov_b32_e32 v0, s21
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v1, vcc
; SI-NEXT:    v_cndmask_b32_e32 v0, 0, v0, vcc
; SI-NEXT:    v_mov_b32_e32 v2, s11
; SI-NEXT:    v_add_i32_e32 v1, vcc, s10, v1
; SI-NEXT:    v_addc_u32_e32 v0, vcc, v2, v0, vcc
; SI-NEXT:    v_not_b32_e32 v2, s0
; SI-NEXT:    v_and_b32_e32 v1, v1, v2
; SI-NEXT:    v_not_b32_e32 v2, s1
; SI-NEXT:    v_mov_b32_e32 v4, 0x3ff00000
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s23, -1
; SI-NEXT:    v_and_b32_e32 v0, v0, v2
; SI-NEXT:    v_cndmask_b32_e32 v2, 0, v4, vcc
; SI-NEXT:    s_brev_b32 s20, -2
; SI-NEXT:    v_mov_b32_e32 v3, s11
; SI-NEXT:    v_bfi_b32 v2, s20, v2, v3
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s23, 0
; SI-NEXT:    v_cndmask_b32_e32 v0, v0, v2, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s23, 51
; SI-NEXT:    v_cndmask_b32_e64 v3, v0, v3, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v0, v1, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v1, s10
; SI-NEXT:    v_cndmask_b32_e64 v2, v0, v1, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s9, 0xb0014
; SI-NEXT:    s_add_i32 s21, s0, s22
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s21
; SI-NEXT:    s_and_b64 s[10:11], s[8:9], s[0:1]
; SI-NEXT:    s_lshr_b64 s[16:17], s[18:19], s21
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[10:11], 0
; SI-NEXT:    v_mov_b32_e32 v1, s16
; SI-NEXT:    v_mov_b32_e32 v0, s17
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v1, vcc
; SI-NEXT:    v_cndmask_b32_e32 v0, 0, v0, vcc
; SI-NEXT:    v_mov_b32_e32 v5, s9
; SI-NEXT:    v_add_i32_e32 v1, vcc, s8, v1
; SI-NEXT:    v_addc_u32_e32 v0, vcc, v5, v0, vcc
; SI-NEXT:    v_not_b32_e32 v5, s0
; SI-NEXT:    v_and_b32_e32 v5, v1, v5
; SI-NEXT:    v_not_b32_e32 v1, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s21, -1
; SI-NEXT:    v_and_b32_e32 v0, v0, v1
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v4, vcc
; SI-NEXT:    v_mov_b32_e32 v6, s9
; SI-NEXT:    v_bfi_b32 v1, s20, v1, v6
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s21, 0
; SI-NEXT:    v_cndmask_b32_e32 v0, v0, v1, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s21, 51
; SI-NEXT:    v_cndmask_b32_e64 v1, v0, v6, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v0, v5, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v5, s8
; SI-NEXT:    v_cndmask_b32_e64 v0, v0, v5, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s15, 0xb0014
; SI-NEXT:    s_add_i32 s16, s0, s22
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s16
; SI-NEXT:    s_and_b64 s[8:9], s[14:15], s[0:1]
; SI-NEXT:    s_lshr_b64 s[10:11], s[18:19], s16
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[8:9], 0
; SI-NEXT:    v_mov_b32_e32 v6, s10
; SI-NEXT:    v_mov_b32_e32 v5, s11
; SI-NEXT:    v_cndmask_b32_e32 v6, 0, v6, vcc
; SI-NEXT:    v_cndmask_b32_e32 v5, 0, v5, vcc
; SI-NEXT:    v_mov_b32_e32 v7, s15
; SI-NEXT:    v_add_i32_e32 v6, vcc, s14, v6
; SI-NEXT:    v_addc_u32_e32 v5, vcc, v7, v5, vcc
; SI-NEXT:    v_not_b32_e32 v7, s0
; SI-NEXT:    v_and_b32_e32 v6, v6, v7
; SI-NEXT:    v_not_b32_e32 v7, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s16, -1
; SI-NEXT:    v_and_b32_e32 v5, v5, v7
; SI-NEXT:    v_cndmask_b32_e32 v7, 0, v4, vcc
; SI-NEXT:    v_mov_b32_e32 v8, s15
; SI-NEXT:    v_bfi_b32 v7, s20, v7, v8
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s16, 0
; SI-NEXT:    v_cndmask_b32_e32 v5, v5, v7, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s16, 51
; SI-NEXT:    v_cndmask_b32_e64 v7, v5, v8, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v5, v6, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v6, s14
; SI-NEXT:    v_cndmask_b32_e64 v6, v5, v6, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s13, 0xb0014
; SI-NEXT:    s_add_i32 s10, s0, s22
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s10
; SI-NEXT:    s_and_b64 s[2:3], s[12:13], s[0:1]
; SI-NEXT:    s_lshr_b64 s[8:9], s[18:19], s10
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[2:3], 0
; SI-NEXT:    v_mov_b32_e32 v8, s8
; SI-NEXT:    v_mov_b32_e32 v5, s9
; SI-NEXT:    v_cndmask_b32_e32 v8, 0, v8, vcc
; SI-NEXT:    v_cndmask_b32_e32 v5, 0, v5, vcc
; SI-NEXT:    v_mov_b32_e32 v9, s13
; SI-NEXT:    v_add_i32_e32 v8, vcc, s12, v8
; SI-NEXT:    v_addc_u32_e32 v5, vcc, v9, v5, vcc
; SI-NEXT:    v_not_b32_e32 v9, s0
; SI-NEXT:    v_and_b32_e32 v8, v8, v9
; SI-NEXT:    v_not_b32_e32 v9, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s10, -1
; SI-NEXT:    v_and_b32_e32 v5, v5, v9
; SI-NEXT:    v_cndmask_b32_e32 v4, 0, v4, vcc
; SI-NEXT:    v_mov_b32_e32 v9, s13
; SI-NEXT:    v_bfi_b32 v4, s20, v4, v9
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s10, 0
; SI-NEXT:    v_cndmask_b32_e32 v4, v5, v4, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s10, 51
; SI-NEXT:    v_cndmask_b32_e64 v5, v4, v9, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v4, v8, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v8, s12
; SI-NEXT:    s_mov_b32 s7, 0xf000
; SI-NEXT:    v_cndmask_b32_e64 v4, v4, v8, s[0:1]
; SI-NEXT:    buffer_store_dwordx4 v[4:7], off, s[4:7], 0 offset:16
; SI-NEXT:    buffer_store_dwordx4 v[0:3], off, s[4:7], 0
; SI-NEXT:    s_endpgm
;
; CI-LABEL: round_v4f64:
; CI:       ; %bb.0:
; CI-NEXT:    s_load_dwordx2 s[8:9], s[0:1], 0x9
; CI-NEXT:    s_load_dwordx8 s[0:7], s[0:1], 0x11
; CI-NEXT:    s_brev_b32 s12, -2
; CI-NEXT:    v_mov_b32_e32 v12, 0x3ff00000
; CI-NEXT:    s_mov_b32 s11, 0xf000
; CI-NEXT:    s_mov_b32 s10, -1
; CI-NEXT:    s_waitcnt lgkmcnt(0)
; CI-NEXT:    v_trunc_f64_e32 v[0:1], s[2:3]
; CI-NEXT:    v_mov_b32_e32 v4, s3
; CI-NEXT:    v_add_f64 v[2:3], s[2:3], -v[0:1]
; CI-NEXT:    v_bfi_b32 v4, s12, v12, v4
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[2:3]|, 0.5
; CI-NEXT:    v_trunc_f64_e32 v[8:9], s[0:1]
; CI-NEXT:    v_cndmask_b32_e32 v3, 0, v4, vcc
; CI-NEXT:    v_mov_b32_e32 v2, 0
; CI-NEXT:    v_add_f64 v[2:3], v[0:1], v[2:3]
; CI-NEXT:    v_add_f64 v[0:1], s[0:1], -v[8:9]
; CI-NEXT:    v_mov_b32_e32 v4, s1
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[0:1]|, 0.5
; CI-NEXT:    v_bfi_b32 v4, s12, v12, v4
; CI-NEXT:    v_cndmask_b32_e32 v1, 0, v4, vcc
; CI-NEXT:    v_trunc_f64_e32 v[4:5], s[6:7]
; CI-NEXT:    v_mov_b32_e32 v10, s7
; CI-NEXT:    v_add_f64 v[6:7], s[6:7], -v[4:5]
; CI-NEXT:    v_bfi_b32 v10, s12, v12, v10
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[6:7]|, 0.5
; CI-NEXT:    v_mov_b32_e32 v6, 0
; CI-NEXT:    v_cndmask_b32_e32 v7, 0, v10, vcc
; CI-NEXT:    v_trunc_f64_e32 v[10:11], s[4:5]
; CI-NEXT:    v_add_f64 v[6:7], v[4:5], v[6:7]
; CI-NEXT:    v_add_f64 v[4:5], s[4:5], -v[10:11]
; CI-NEXT:    v_mov_b32_e32 v13, s5
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[4:5]|, 0.5
; CI-NEXT:    v_bfi_b32 v12, s12, v12, v13
; CI-NEXT:    v_mov_b32_e32 v0, 0
; CI-NEXT:    v_cndmask_b32_e32 v5, 0, v12, vcc
; CI-NEXT:    v_mov_b32_e32 v4, 0
; CI-NEXT:    v_add_f64 v[4:5], v[10:11], v[4:5]
; CI-NEXT:    v_add_f64 v[0:1], v[8:9], v[0:1]
; CI-NEXT:    buffer_store_dwordx4 v[4:7], off, s[8:11], 0 offset:16
; CI-NEXT:    buffer_store_dwordx4 v[0:3], off, s[8:11], 0
; CI-NEXT:    s_endpgm
  %result = call <4 x double> @llvm.round.v4f64(<4 x double> %in) #1
  store <4 x double> %result, <4 x double> addrspace(1)* %out
  ret void
}

define amdgpu_kernel void @round_v8f64(<8 x double> addrspace(1)* %out, <8 x double> %in) #0 {
; SI-LABEL: round_v8f64:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x9
; SI-NEXT:    s_load_dwordx16 s[8:23], s[0:1], 0x19
; SI-NEXT:    s_mov_b32 s6, -1
; SI-NEXT:    s_movk_i32 s30, 0xfc01
; SI-NEXT:    s_mov_b32 s3, 0xfffff
; SI-NEXT:    s_mov_b32 s2, s6
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_bfe_u32 s0, s11, 0xb0014
; SI-NEXT:    s_add_i32 s31, s0, s30
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s31
; SI-NEXT:    s_and_b64 s[26:27], s[10:11], s[0:1]
; SI-NEXT:    s_mov_b32 s25, 0x80000
; SI-NEXT:    s_mov_b32 s24, 0
; SI-NEXT:    s_lshr_b64 s[28:29], s[24:25], s31
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[26:27], 0
; SI-NEXT:    v_mov_b32_e32 v1, s28
; SI-NEXT:    v_mov_b32_e32 v0, s29
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v1, vcc
; SI-NEXT:    v_cndmask_b32_e32 v0, 0, v0, vcc
; SI-NEXT:    v_mov_b32_e32 v2, s11
; SI-NEXT:    v_add_i32_e32 v1, vcc, s10, v1
; SI-NEXT:    v_addc_u32_e32 v0, vcc, v2, v0, vcc
; SI-NEXT:    v_not_b32_e32 v2, s0
; SI-NEXT:    v_and_b32_e32 v1, v1, v2
; SI-NEXT:    v_not_b32_e32 v2, s1
; SI-NEXT:    v_mov_b32_e32 v12, 0x3ff00000
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s31, -1
; SI-NEXT:    v_and_b32_e32 v0, v0, v2
; SI-NEXT:    v_cndmask_b32_e32 v2, 0, v12, vcc
; SI-NEXT:    s_brev_b32 s28, -2
; SI-NEXT:    v_mov_b32_e32 v3, s11
; SI-NEXT:    v_bfi_b32 v2, s28, v2, v3
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s31, 0
; SI-NEXT:    v_cndmask_b32_e32 v0, v0, v2, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s31, 51
; SI-NEXT:    v_cndmask_b32_e64 v3, v0, v3, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v0, v1, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v1, s10
; SI-NEXT:    v_cndmask_b32_e64 v2, v0, v1, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s9, 0xb0014
; SI-NEXT:    s_add_i32 s29, s0, s30
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s29
; SI-NEXT:    s_and_b64 s[10:11], s[8:9], s[0:1]
; SI-NEXT:    s_lshr_b64 s[26:27], s[24:25], s29
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[10:11], 0
; SI-NEXT:    v_mov_b32_e32 v1, s26
; SI-NEXT:    v_mov_b32_e32 v0, s27
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v1, vcc
; SI-NEXT:    v_cndmask_b32_e32 v0, 0, v0, vcc
; SI-NEXT:    v_mov_b32_e32 v4, s9
; SI-NEXT:    v_add_i32_e32 v1, vcc, s8, v1
; SI-NEXT:    v_addc_u32_e32 v0, vcc, v4, v0, vcc
; SI-NEXT:    v_not_b32_e32 v4, s0
; SI-NEXT:    v_and_b32_e32 v4, v1, v4
; SI-NEXT:    v_not_b32_e32 v1, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s29, -1
; SI-NEXT:    v_and_b32_e32 v0, v0, v1
; SI-NEXT:    v_cndmask_b32_e32 v1, 0, v12, vcc
; SI-NEXT:    v_mov_b32_e32 v5, s9
; SI-NEXT:    v_bfi_b32 v1, s28, v1, v5
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s29, 0
; SI-NEXT:    v_cndmask_b32_e32 v0, v0, v1, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s29, 51
; SI-NEXT:    v_cndmask_b32_e64 v1, v0, v5, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v0, v4, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v4, s8
; SI-NEXT:    v_cndmask_b32_e64 v0, v0, v4, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s15, 0xb0014
; SI-NEXT:    s_add_i32 s26, s0, s30
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s26
; SI-NEXT:    s_and_b64 s[8:9], s[14:15], s[0:1]
; SI-NEXT:    s_lshr_b64 s[10:11], s[24:25], s26
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[8:9], 0
; SI-NEXT:    v_mov_b32_e32 v5, s10
; SI-NEXT:    v_mov_b32_e32 v4, s11
; SI-NEXT:    v_cndmask_b32_e32 v5, 0, v5, vcc
; SI-NEXT:    v_cndmask_b32_e32 v4, 0, v4, vcc
; SI-NEXT:    v_mov_b32_e32 v6, s15
; SI-NEXT:    v_add_i32_e32 v5, vcc, s14, v5
; SI-NEXT:    v_addc_u32_e32 v4, vcc, v6, v4, vcc
; SI-NEXT:    v_not_b32_e32 v6, s0
; SI-NEXT:    v_and_b32_e32 v5, v5, v6
; SI-NEXT:    v_not_b32_e32 v6, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s26, -1
; SI-NEXT:    v_and_b32_e32 v4, v4, v6
; SI-NEXT:    v_cndmask_b32_e32 v6, 0, v12, vcc
; SI-NEXT:    v_mov_b32_e32 v7, s15
; SI-NEXT:    v_bfi_b32 v6, s28, v6, v7
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s26, 0
; SI-NEXT:    v_cndmask_b32_e32 v4, v4, v6, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s26, 51
; SI-NEXT:    v_cndmask_b32_e64 v7, v4, v7, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v4, v5, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v5, s14
; SI-NEXT:    v_cndmask_b32_e64 v6, v4, v5, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s13, 0xb0014
; SI-NEXT:    s_add_i32 s14, s0, s30
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s14
; SI-NEXT:    s_and_b64 s[8:9], s[12:13], s[0:1]
; SI-NEXT:    s_lshr_b64 s[10:11], s[24:25], s14
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[8:9], 0
; SI-NEXT:    v_mov_b32_e32 v5, s10
; SI-NEXT:    v_mov_b32_e32 v4, s11
; SI-NEXT:    v_cndmask_b32_e32 v5, 0, v5, vcc
; SI-NEXT:    v_cndmask_b32_e32 v4, 0, v4, vcc
; SI-NEXT:    v_mov_b32_e32 v8, s13
; SI-NEXT:    v_add_i32_e32 v5, vcc, s12, v5
; SI-NEXT:    v_addc_u32_e32 v4, vcc, v8, v4, vcc
; SI-NEXT:    v_not_b32_e32 v8, s0
; SI-NEXT:    v_and_b32_e32 v8, v5, v8
; SI-NEXT:    v_not_b32_e32 v5, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s14, -1
; SI-NEXT:    v_and_b32_e32 v4, v4, v5
; SI-NEXT:    v_cndmask_b32_e32 v5, 0, v12, vcc
; SI-NEXT:    v_mov_b32_e32 v9, s13
; SI-NEXT:    v_bfi_b32 v5, s28, v5, v9
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s14, 0
; SI-NEXT:    v_cndmask_b32_e32 v4, v4, v5, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s14, 51
; SI-NEXT:    v_cndmask_b32_e64 v5, v4, v9, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v4, v8, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v8, s12
; SI-NEXT:    v_cndmask_b32_e64 v4, v4, v8, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s19, 0xb0014
; SI-NEXT:    s_add_i32 s12, s0, s30
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s12
; SI-NEXT:    s_and_b64 s[8:9], s[18:19], s[0:1]
; SI-NEXT:    s_lshr_b64 s[10:11], s[24:25], s12
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[8:9], 0
; SI-NEXT:    v_mov_b32_e32 v9, s10
; SI-NEXT:    v_mov_b32_e32 v8, s11
; SI-NEXT:    v_cndmask_b32_e32 v9, 0, v9, vcc
; SI-NEXT:    v_cndmask_b32_e32 v8, 0, v8, vcc
; SI-NEXT:    v_mov_b32_e32 v10, s19
; SI-NEXT:    v_add_i32_e32 v9, vcc, s18, v9
; SI-NEXT:    v_addc_u32_e32 v8, vcc, v10, v8, vcc
; SI-NEXT:    v_not_b32_e32 v10, s0
; SI-NEXT:    v_and_b32_e32 v9, v9, v10
; SI-NEXT:    v_not_b32_e32 v10, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s12, -1
; SI-NEXT:    v_and_b32_e32 v8, v8, v10
; SI-NEXT:    v_cndmask_b32_e32 v10, 0, v12, vcc
; SI-NEXT:    v_mov_b32_e32 v11, s19
; SI-NEXT:    v_bfi_b32 v10, s28, v10, v11
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s12, 0
; SI-NEXT:    v_cndmask_b32_e32 v8, v8, v10, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s12, 51
; SI-NEXT:    v_cndmask_b32_e64 v11, v8, v11, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v8, v9, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v9, s18
; SI-NEXT:    v_cndmask_b32_e64 v10, v8, v9, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s17, 0xb0014
; SI-NEXT:    s_add_i32 s12, s0, s30
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s12
; SI-NEXT:    s_and_b64 s[8:9], s[16:17], s[0:1]
; SI-NEXT:    s_lshr_b64 s[10:11], s[24:25], s12
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[8:9], 0
; SI-NEXT:    v_mov_b32_e32 v9, s10
; SI-NEXT:    v_mov_b32_e32 v8, s11
; SI-NEXT:    v_cndmask_b32_e32 v9, 0, v9, vcc
; SI-NEXT:    v_cndmask_b32_e32 v8, 0, v8, vcc
; SI-NEXT:    v_mov_b32_e32 v13, s17
; SI-NEXT:    v_add_i32_e32 v9, vcc, s16, v9
; SI-NEXT:    v_addc_u32_e32 v8, vcc, v13, v8, vcc
; SI-NEXT:    v_not_b32_e32 v13, s0
; SI-NEXT:    v_and_b32_e32 v13, v9, v13
; SI-NEXT:    v_not_b32_e32 v9, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s12, -1
; SI-NEXT:    v_and_b32_e32 v8, v8, v9
; SI-NEXT:    v_cndmask_b32_e32 v9, 0, v12, vcc
; SI-NEXT:    v_mov_b32_e32 v14, s17
; SI-NEXT:    v_bfi_b32 v9, s28, v9, v14
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s12, 0
; SI-NEXT:    v_cndmask_b32_e32 v8, v8, v9, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s12, 51
; SI-NEXT:    v_cndmask_b32_e64 v9, v8, v14, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v8, v13, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v13, s16
; SI-NEXT:    v_cndmask_b32_e64 v8, v8, v13, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s23, 0xb0014
; SI-NEXT:    s_add_i32 s12, s0, s30
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s12
; SI-NEXT:    s_and_b64 s[8:9], s[22:23], s[0:1]
; SI-NEXT:    s_lshr_b64 s[10:11], s[24:25], s12
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[8:9], 0
; SI-NEXT:    v_mov_b32_e32 v14, s10
; SI-NEXT:    v_mov_b32_e32 v13, s11
; SI-NEXT:    v_cndmask_b32_e32 v14, 0, v14, vcc
; SI-NEXT:    v_cndmask_b32_e32 v13, 0, v13, vcc
; SI-NEXT:    v_mov_b32_e32 v15, s23
; SI-NEXT:    v_add_i32_e32 v14, vcc, s22, v14
; SI-NEXT:    v_addc_u32_e32 v13, vcc, v15, v13, vcc
; SI-NEXT:    v_not_b32_e32 v15, s0
; SI-NEXT:    v_and_b32_e32 v14, v14, v15
; SI-NEXT:    v_not_b32_e32 v15, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s12, -1
; SI-NEXT:    v_and_b32_e32 v13, v13, v15
; SI-NEXT:    v_cndmask_b32_e32 v15, 0, v12, vcc
; SI-NEXT:    v_mov_b32_e32 v16, s23
; SI-NEXT:    v_bfi_b32 v15, s28, v15, v16
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s12, 0
; SI-NEXT:    v_cndmask_b32_e32 v13, v13, v15, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s12, 51
; SI-NEXT:    v_cndmask_b32_e64 v15, v13, v16, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v13, v14, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v14, s22
; SI-NEXT:    v_cndmask_b32_e64 v14, v13, v14, s[0:1]
; SI-NEXT:    s_bfe_u32 s0, s21, 0xb0014
; SI-NEXT:    s_add_i32 s10, s0, s30
; SI-NEXT:    s_lshr_b64 s[0:1], s[2:3], s10
; SI-NEXT:    s_and_b64 s[2:3], s[20:21], s[0:1]
; SI-NEXT:    s_lshr_b64 s[8:9], s[24:25], s10
; SI-NEXT:    v_cmp_ne_u64_e64 vcc, s[2:3], 0
; SI-NEXT:    v_mov_b32_e32 v16, s8
; SI-NEXT:    v_mov_b32_e32 v13, s9
; SI-NEXT:    v_cndmask_b32_e32 v16, 0, v16, vcc
; SI-NEXT:    v_cndmask_b32_e32 v13, 0, v13, vcc
; SI-NEXT:    v_mov_b32_e32 v17, s21
; SI-NEXT:    v_add_i32_e32 v16, vcc, s20, v16
; SI-NEXT:    v_addc_u32_e32 v13, vcc, v17, v13, vcc
; SI-NEXT:    v_not_b32_e32 v17, s0
; SI-NEXT:    v_and_b32_e32 v16, v16, v17
; SI-NEXT:    v_not_b32_e32 v17, s1
; SI-NEXT:    v_cmp_eq_u32_e64 vcc, s10, -1
; SI-NEXT:    v_and_b32_e32 v13, v13, v17
; SI-NEXT:    v_cndmask_b32_e32 v12, 0, v12, vcc
; SI-NEXT:    v_mov_b32_e32 v17, s21
; SI-NEXT:    v_bfi_b32 v12, s28, v12, v17
; SI-NEXT:    v_cmp_lt_i32_e64 vcc, s10, 0
; SI-NEXT:    v_cndmask_b32_e32 v12, v13, v12, vcc
; SI-NEXT:    v_cmp_gt_i32_e64 s[0:1], s10, 51
; SI-NEXT:    v_cndmask_b32_e64 v13, v12, v17, s[0:1]
; SI-NEXT:    v_cndmask_b32_e64 v12, v16, 0, vcc
; SI-NEXT:    v_mov_b32_e32 v16, s20
; SI-NEXT:    s_mov_b32 s7, 0xf000
; SI-NEXT:    v_cndmask_b32_e64 v12, v12, v16, s[0:1]
; SI-NEXT:    buffer_store_dwordx4 v[12:15], off, s[4:7], 0 offset:48
; SI-NEXT:    buffer_store_dwordx4 v[8:11], off, s[4:7], 0 offset:32
; SI-NEXT:    buffer_store_dwordx4 v[4:7], off, s[4:7], 0 offset:16
; SI-NEXT:    buffer_store_dwordx4 v[0:3], off, s[4:7], 0
; SI-NEXT:    s_endpgm
;
; CI-LABEL: round_v8f64:
; CI:       ; %bb.0:
; CI-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x9
; CI-NEXT:    s_load_dwordx16 s[8:23], s[0:1], 0x19
; CI-NEXT:    s_brev_b32 s2, -2
; CI-NEXT:    v_mov_b32_e32 v16, 0x3ff00000
; CI-NEXT:    s_mov_b32 s7, 0xf000
; CI-NEXT:    s_mov_b32 s6, -1
; CI-NEXT:    s_waitcnt lgkmcnt(0)
; CI-NEXT:    v_trunc_f64_e32 v[0:1], s[10:11]
; CI-NEXT:    v_mov_b32_e32 v4, s11
; CI-NEXT:    v_add_f64 v[2:3], s[10:11], -v[0:1]
; CI-NEXT:    v_bfi_b32 v4, s2, v16, v4
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[2:3]|, 0.5
; CI-NEXT:    v_mov_b32_e32 v2, 0
; CI-NEXT:    v_cndmask_b32_e32 v3, 0, v4, vcc
; CI-NEXT:    v_trunc_f64_e32 v[4:5], s[8:9]
; CI-NEXT:    v_add_f64 v[2:3], v[0:1], v[2:3]
; CI-NEXT:    v_add_f64 v[0:1], s[8:9], -v[4:5]
; CI-NEXT:    v_mov_b32_e32 v6, s9
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[0:1]|, 0.5
; CI-NEXT:    v_bfi_b32 v6, s2, v16, v6
; CI-NEXT:    v_cndmask_b32_e32 v1, 0, v6, vcc
; CI-NEXT:    v_trunc_f64_e32 v[6:7], s[14:15]
; CI-NEXT:    v_mov_b32_e32 v0, 0
; CI-NEXT:    v_add_f64 v[0:1], v[4:5], v[0:1]
; CI-NEXT:    v_add_f64 v[4:5], s[14:15], -v[6:7]
; CI-NEXT:    v_mov_b32_e32 v8, s15
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[4:5]|, 0.5
; CI-NEXT:    v_bfi_b32 v8, s2, v16, v8
; CI-NEXT:    v_cndmask_b32_e32 v5, 0, v8, vcc
; CI-NEXT:    v_trunc_f64_e32 v[8:9], s[12:13]
; CI-NEXT:    v_mov_b32_e32 v4, 0
; CI-NEXT:    v_add_f64 v[6:7], v[6:7], v[4:5]
; CI-NEXT:    v_add_f64 v[4:5], s[12:13], -v[8:9]
; CI-NEXT:    v_mov_b32_e32 v10, s13
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[4:5]|, 0.5
; CI-NEXT:    v_bfi_b32 v10, s2, v16, v10
; CI-NEXT:    v_cndmask_b32_e32 v5, 0, v10, vcc
; CI-NEXT:    v_mov_b32_e32 v4, 0
; CI-NEXT:    v_add_f64 v[4:5], v[8:9], v[4:5]
; CI-NEXT:    v_mov_b32_e32 v8, s19
; CI-NEXT:    v_bfi_b32 v18, s2, v16, v8
; CI-NEXT:    v_trunc_f64_e32 v[8:9], s[20:21]
; CI-NEXT:    v_trunc_f64_e32 v[10:11], s[22:23]
; CI-NEXT:    v_add_f64 v[14:15], s[20:21], -v[8:9]
; CI-NEXT:    v_mov_b32_e32 v19, s23
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[14:15]|, 0.5
; CI-NEXT:    v_add_f64 v[14:15], s[22:23], -v[10:11]
; CI-NEXT:    v_mov_b32_e32 v17, s21
; CI-NEXT:    v_cmp_ge_f64_e64 s[0:1], |v[14:15]|, 0.5
; CI-NEXT:    v_bfi_b32 v19, s2, v16, v19
; CI-NEXT:    v_trunc_f64_e32 v[12:13], s[16:17]
; CI-NEXT:    v_bfi_b32 v17, s2, v16, v17
; CI-NEXT:    v_cndmask_b32_e64 v15, 0, v19, s[0:1]
; CI-NEXT:    v_mov_b32_e32 v14, 0
; CI-NEXT:    v_add_f64 v[10:11], v[10:11], v[14:15]
; CI-NEXT:    v_cndmask_b32_e32 v15, 0, v17, vcc
; CI-NEXT:    v_mov_b32_e32 v14, 0
; CI-NEXT:    v_mov_b32_e32 v17, s17
; CI-NEXT:    v_add_f64 v[8:9], v[8:9], v[14:15]
; CI-NEXT:    v_add_f64 v[14:15], s[16:17], -v[12:13]
; CI-NEXT:    v_bfi_b32 v19, s2, v16, v17
; CI-NEXT:    v_trunc_f64_e32 v[16:17], s[18:19]
; CI-NEXT:    v_cmp_ge_f64_e64 vcc, |v[14:15]|, 0.5
; CI-NEXT:    v_add_f64 v[14:15], s[18:19], -v[16:17]
; CI-NEXT:    v_cmp_ge_f64_e64 s[0:1], |v[14:15]|, 0.5
; CI-NEXT:    v_mov_b32_e32 v14, 0
; CI-NEXT:    v_cndmask_b32_e64 v15, 0, v18, s[0:1]
; CI-NEXT:    v_add_f64 v[14:15], v[16:17], v[14:15]
; CI-NEXT:    v_cndmask_b32_e32 v17, 0, v19, vcc
; CI-NEXT:    v_mov_b32_e32 v16, 0
; CI-NEXT:    v_add_f64 v[12:13], v[12:13], v[16:17]
; CI-NEXT:    buffer_store_dwordx4 v[8:11], off, s[4:7], 0 offset:48
; CI-NEXT:    buffer_store_dwordx4 v[12:15], off, s[4:7], 0 offset:32
; CI-NEXT:    buffer_store_dwordx4 v[4:7], off, s[4:7], 0 offset:16
; CI-NEXT:    buffer_store_dwordx4 v[0:3], off, s[4:7], 0
; CI-NEXT:    s_endpgm
  %result = call <8 x double> @llvm.round.v8f64(<8 x double> %in) #1
  store <8 x double> %result, <8 x double> addrspace(1)* %out
  ret void
}

declare i32 @llvm.amdgcn.workitem.id.x() #1

declare double @llvm.round.f64(double) #1
declare <2 x double> @llvm.round.v2f64(<2 x double>) #1
declare <4 x double> @llvm.round.v4f64(<4 x double>) #1
declare <8 x double> @llvm.round.v8f64(<8 x double>) #1

attributes #0 = { nounwind }
attributes #1 = { nounwind readnone }
