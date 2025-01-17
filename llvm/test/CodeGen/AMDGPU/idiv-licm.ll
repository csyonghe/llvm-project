; Modifications Copyright (c) 2019 Advanced Micro Devices, Inc. All rights reserved.
; Notified per clause 4(b) of the license.
; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -march=amdgcn -mcpu=gfx900 -verify-machineinstrs < %s | FileCheck -enable-var-scope -check-prefix=GFX9 %s

define amdgpu_kernel void @udiv32_invariant_denom(i32 addrspace(1)* nocapture %arg, i32 %arg1) {
; GFX9-LABEL: udiv32_invariant_denom:
; GFX9:       ; %bb.0: ; %bb
; GFX9-NEXT:    s_load_dword s2, s[0:1], 0x2c
; GFX9-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x24
; GFX9-NEXT:    s_mov_b64 s[6:7], 0
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    v_cvt_f32_u32_e32 v0, s2
; GFX9-NEXT:    s_sub_i32 s3, 0, s2
; GFX9-NEXT:    v_rcp_iflag_f32_e32 v0, v0
; GFX9-NEXT:    v_mul_f32_e32 v0, 0x4f800000, v0
; GFX9-NEXT:    v_cvt_u32_f32_e32 v0, v0
; GFX9-NEXT:    v_mul_lo_u32 v1, v0, s2
; GFX9-NEXT:    v_mul_hi_u32 v2, v0, s2
; GFX9-NEXT:    v_sub_u32_e32 v3, 0, v1
; GFX9-NEXT:    v_cmp_eq_u32_e32 vcc, 0, v2
; GFX9-NEXT:    v_cndmask_b32_e32 v1, v1, v3, vcc
; GFX9-NEXT:    v_mul_hi_u32 v1, v1, v0
; GFX9-NEXT:    v_add_u32_e32 v2, v0, v1
; GFX9-NEXT:    v_sub_u32_e32 v0, v0, v1
; GFX9-NEXT:    v_cndmask_b32_e32 v0, v0, v2, vcc
; GFX9-NEXT:  BB0_1: ; %bb3
; GFX9-NEXT:    ; =>This Inner Loop Header: Depth=1
; GFX9-NEXT:    v_mul_lo_u32 v3, v0, s7
; GFX9-NEXT:    v_mul_hi_u32 v4, v0, s6
; GFX9-NEXT:    v_mov_b32_e32 v1, s4
; GFX9-NEXT:    v_mov_b32_e32 v2, s5
; GFX9-NEXT:    v_add_u32_e32 v3, v4, v3
; GFX9-NEXT:    v_mul_lo_u32 v4, s3, v3
; GFX9-NEXT:    v_mul_lo_u32 v5, v3, s2
; GFX9-NEXT:    v_add_u32_e32 v6, 1, v3
; GFX9-NEXT:    v_add_u32_e32 v7, -1, v3
; GFX9-NEXT:    v_add_u32_e32 v4, s6, v4
; GFX9-NEXT:    v_cmp_ge_u32_e32 vcc, s6, v5
; GFX9-NEXT:    v_cmp_le_u32_e64 s[0:1], s2, v4
; GFX9-NEXT:    s_and_b64 s[0:1], s[0:1], vcc
; GFX9-NEXT:    s_add_u32 s6, s6, 1
; GFX9-NEXT:    s_addc_u32 s7, s7, 0
; GFX9-NEXT:    s_add_u32 s4, s4, 4
; GFX9-NEXT:    v_cndmask_b32_e64 v3, v3, v6, s[0:1]
; GFX9-NEXT:    s_addc_u32 s5, s5, 0
; GFX9-NEXT:    v_cndmask_b32_e32 v3, v7, v3, vcc
; GFX9-NEXT:    s_cmpk_eq_i32 s6, 0x400
; GFX9-NEXT:    global_store_dword v[1:2], v3, off
; GFX9-NEXT:    s_cbranch_scc0 BB0_1
; GFX9-NEXT:  ; %bb.2: ; %bb2
; GFX9-NEXT:    s_endpgm
bb:
  br label %bb3

bb2:                                              ; preds = %bb3
  ret void

bb3:                                              ; preds = %bb3, %bb
  %tmp = phi i32 [ 0, %bb ], [ %tmp7, %bb3 ]
  %tmp4 = udiv i32 %tmp, %arg1
  %tmp5 = zext i32 %tmp to i64
  %tmp6 = getelementptr inbounds i32, i32 addrspace(1)* %arg, i64 %tmp5
  store i32 %tmp4, i32 addrspace(1)* %tmp6, align 4
  %tmp7 = add nuw nsw i32 %tmp, 1
  %tmp8 = icmp eq i32 %tmp7, 1024
  br i1 %tmp8, label %bb2, label %bb3
}

define amdgpu_kernel void @urem32_invariant_denom(i32 addrspace(1)* nocapture %arg, i32 %arg1) {
; GFX9-LABEL: urem32_invariant_denom:
; GFX9:       ; %bb.0: ; %bb
; GFX9-NEXT:    s_load_dword s2, s[0:1], 0x2c
; GFX9-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x24
; GFX9-NEXT:    s_mov_b64 s[6:7], 0
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    v_cvt_f32_u32_e32 v0, s2
; GFX9-NEXT:    s_sub_i32 s3, 0, s2
; GFX9-NEXT:    v_rcp_iflag_f32_e32 v0, v0
; GFX9-NEXT:    v_mul_f32_e32 v0, 0x4f800000, v0
; GFX9-NEXT:    v_cvt_u32_f32_e32 v0, v0
; GFX9-NEXT:    v_mul_lo_u32 v1, v0, s2
; GFX9-NEXT:    v_mul_hi_u32 v2, v0, s2
; GFX9-NEXT:    v_sub_u32_e32 v3, 0, v1
; GFX9-NEXT:    v_cmp_eq_u32_e32 vcc, 0, v2
; GFX9-NEXT:    v_cndmask_b32_e32 v1, v1, v3, vcc
; GFX9-NEXT:    v_mul_hi_u32 v1, v1, v0
; GFX9-NEXT:    v_add_u32_e32 v2, v0, v1
; GFX9-NEXT:    v_sub_u32_e32 v0, v0, v1
; GFX9-NEXT:    v_cndmask_b32_e32 v0, v0, v2, vcc
; GFX9-NEXT:  BB1_1: ; %bb3
; GFX9-NEXT:    ; =>This Inner Loop Header: Depth=1
; GFX9-NEXT:    v_mul_lo_u32 v3, v0, s7
; GFX9-NEXT:    v_mul_hi_u32 v4, v0, s6
; GFX9-NEXT:    v_mov_b32_e32 v1, s4
; GFX9-NEXT:    v_mov_b32_e32 v2, s5
; GFX9-NEXT:    v_add_u32_e32 v3, v4, v3
; GFX9-NEXT:    v_mul_lo_u32 v5, s3, v3
; GFX9-NEXT:    v_mul_lo_u32 v4, v3, s2
; GFX9-NEXT:    v_not_b32_e32 v6, v3
; GFX9-NEXT:    v_sub_u32_e32 v3, 1, v3
; GFX9-NEXT:    v_mul_lo_u32 v3, s2, v3
; GFX9-NEXT:    v_mul_lo_u32 v6, s2, v6
; GFX9-NEXT:    v_add_u32_e32 v5, s6, v5
; GFX9-NEXT:    v_cmp_ge_u32_e64 s[0:1], s6, v4
; GFX9-NEXT:    v_cmp_le_u32_e32 vcc, s2, v5
; GFX9-NEXT:    s_and_b64 vcc, vcc, s[0:1]
; GFX9-NEXT:    v_add_u32_e32 v4, s6, v6
; GFX9-NEXT:    v_add_u32_e32 v3, s6, v3
; GFX9-NEXT:    s_add_u32 s6, s6, 1
; GFX9-NEXT:    s_addc_u32 s7, s7, 0
; GFX9-NEXT:    s_add_u32 s4, s4, 4
; GFX9-NEXT:    s_addc_u32 s5, s5, 0
; GFX9-NEXT:    v_cndmask_b32_e32 v4, v5, v4, vcc
; GFX9-NEXT:    v_cndmask_b32_e64 v3, v3, v4, s[0:1]
; GFX9-NEXT:    s_cmpk_eq_i32 s6, 0x400
; GFX9-NEXT:    global_store_dword v[1:2], v3, off
; GFX9-NEXT:    s_cbranch_scc0 BB1_1
; GFX9-NEXT:  ; %bb.2: ; %bb2
; GFX9-NEXT:    s_endpgm
bb:
  br label %bb3

bb2:                                              ; preds = %bb3
  ret void

bb3:                                              ; preds = %bb3, %bb
  %tmp = phi i32 [ 0, %bb ], [ %tmp7, %bb3 ]
  %tmp4 = urem i32 %tmp, %arg1
  %tmp5 = zext i32 %tmp to i64
  %tmp6 = getelementptr inbounds i32, i32 addrspace(1)* %arg, i64 %tmp5
  store i32 %tmp4, i32 addrspace(1)* %tmp6, align 4
  %tmp7 = add nuw nsw i32 %tmp, 1
  %tmp8 = icmp eq i32 %tmp7, 1024
  br i1 %tmp8, label %bb2, label %bb3
}

define amdgpu_kernel void @sdiv32_invariant_denom(i32 addrspace(1)* nocapture %arg, i32 %arg1) {
; GFX9-LABEL: sdiv32_invariant_denom:
; GFX9:       ; %bb.0: ; %bb
; GFX9-NEXT:    s_load_dword s3, s[0:1], 0x2c
; GFX9-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x24
; GFX9-NEXT:    s_mov_b32 s6, 0
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    s_ashr_i32 s2, s3, 31
; GFX9-NEXT:    s_add_i32 s3, s3, s2
; GFX9-NEXT:    s_xor_b32 s3, s3, s2
; GFX9-NEXT:    v_cvt_f32_u32_e32 v0, s3
; GFX9-NEXT:    v_rcp_iflag_f32_e32 v0, v0
; GFX9-NEXT:    v_mul_f32_e32 v0, 0x4f800000, v0
; GFX9-NEXT:    v_cvt_u32_f32_e32 v0, v0
; GFX9-NEXT:    v_mul_lo_u32 v1, v0, s3
; GFX9-NEXT:    v_mul_hi_u32 v2, v0, s3
; GFX9-NEXT:    v_sub_u32_e32 v3, 0, v1
; GFX9-NEXT:    v_cmp_eq_u32_e32 vcc, 0, v2
; GFX9-NEXT:    v_cndmask_b32_e32 v1, v1, v3, vcc
; GFX9-NEXT:    v_mul_hi_u32 v1, v1, v0
; GFX9-NEXT:    v_add_u32_e32 v2, v0, v1
; GFX9-NEXT:    v_sub_u32_e32 v0, v0, v1
; GFX9-NEXT:    v_cndmask_b32_e32 v0, v0, v2, vcc
; GFX9-NEXT:  BB2_1: ; %bb3
; GFX9-NEXT:    ; =>This Inner Loop Header: Depth=1
; GFX9-NEXT:    v_mul_hi_u32 v3, v0, s6
; GFX9-NEXT:    v_mov_b32_e32 v1, s4
; GFX9-NEXT:    v_mov_b32_e32 v2, s5
; GFX9-NEXT:    v_mul_lo_u32 v4, v3, s3
; GFX9-NEXT:    v_add_u32_e32 v5, 1, v3
; GFX9-NEXT:    v_add_u32_e32 v6, -1, v3
; GFX9-NEXT:    v_sub_u32_e32 v7, s6, v4
; GFX9-NEXT:    v_cmp_ge_u32_e32 vcc, s6, v4
; GFX9-NEXT:    v_cmp_le_u32_e64 s[0:1], s3, v7
; GFX9-NEXT:    s_and_b64 s[0:1], s[0:1], vcc
; GFX9-NEXT:    v_cndmask_b32_e64 v3, v3, v5, s[0:1]
; GFX9-NEXT:    s_add_i32 s6, s6, 1
; GFX9-NEXT:    v_cndmask_b32_e32 v3, v6, v3, vcc
; GFX9-NEXT:    s_add_u32 s4, s4, 4
; GFX9-NEXT:    v_xor_b32_e32 v3, s2, v3
; GFX9-NEXT:    s_addc_u32 s5, s5, 0
; GFX9-NEXT:    v_subrev_u32_e32 v3, s2, v3
; GFX9-NEXT:    s_cmpk_eq_i32 s6, 0x400
; GFX9-NEXT:    global_store_dword v[1:2], v3, off
; GFX9-NEXT:    s_cbranch_scc0 BB2_1
; GFX9-NEXT:  ; %bb.2: ; %bb2
; GFX9-NEXT:    s_endpgm
bb:
  br label %bb3

bb2:                                              ; preds = %bb3
  ret void

bb3:                                              ; preds = %bb3, %bb
  %tmp = phi i32 [ 0, %bb ], [ %tmp7, %bb3 ]
  %tmp4 = sdiv i32 %tmp, %arg1
  %tmp5 = zext i32 %tmp to i64
  %tmp6 = getelementptr inbounds i32, i32 addrspace(1)* %arg, i64 %tmp5
  store i32 %tmp4, i32 addrspace(1)* %tmp6, align 4
  %tmp7 = add nuw nsw i32 %tmp, 1
  %tmp8 = icmp eq i32 %tmp7, 1024
  br i1 %tmp8, label %bb2, label %bb3
}

define amdgpu_kernel void @srem32_invariant_denom(i32 addrspace(1)* nocapture %arg, i32 %arg1) {
; GFX9-LABEL: srem32_invariant_denom:
; GFX9:       ; %bb.0: ; %bb
; GFX9-NEXT:    s_load_dword s2, s[0:1], 0x2c
; GFX9-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x24
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    s_ashr_i32 s3, s2, 31
; GFX9-NEXT:    s_add_i32 s2, s2, s3
; GFX9-NEXT:    s_xor_b32 s2, s2, s3
; GFX9-NEXT:    v_cvt_f32_u32_e32 v0, s2
; GFX9-NEXT:    s_mov_b32 s3, 0
; GFX9-NEXT:    v_rcp_iflag_f32_e32 v0, v0
; GFX9-NEXT:    v_mul_f32_e32 v0, 0x4f800000, v0
; GFX9-NEXT:    v_cvt_u32_f32_e32 v0, v0
; GFX9-NEXT:    v_mul_lo_u32 v1, v0, s2
; GFX9-NEXT:    v_mul_hi_u32 v2, v0, s2
; GFX9-NEXT:    v_sub_u32_e32 v3, 0, v1
; GFX9-NEXT:    v_cmp_eq_u32_e32 vcc, 0, v2
; GFX9-NEXT:    v_cndmask_b32_e32 v1, v1, v3, vcc
; GFX9-NEXT:    v_mul_hi_u32 v1, v1, v0
; GFX9-NEXT:    v_add_u32_e32 v2, v0, v1
; GFX9-NEXT:    v_sub_u32_e32 v0, v0, v1
; GFX9-NEXT:    v_cndmask_b32_e32 v0, v0, v2, vcc
; GFX9-NEXT:  BB3_1: ; %bb3
; GFX9-NEXT:    ; =>This Inner Loop Header: Depth=1
; GFX9-NEXT:    v_mul_hi_u32 v3, v0, s3
; GFX9-NEXT:    v_mov_b32_e32 v1, s4
; GFX9-NEXT:    v_mov_b32_e32 v2, s5
; GFX9-NEXT:    v_mul_lo_u32 v3, v3, s2
; GFX9-NEXT:    v_sub_u32_e32 v4, s3, v3
; GFX9-NEXT:    v_cmp_ge_u32_e64 s[0:1], s3, v3
; GFX9-NEXT:    v_cmp_le_u32_e32 vcc, s2, v4
; GFX9-NEXT:    s_add_i32 s3, s3, 1
; GFX9-NEXT:    s_and_b64 vcc, vcc, s[0:1]
; GFX9-NEXT:    v_subrev_u32_e32 v3, s2, v4
; GFX9-NEXT:    s_add_u32 s4, s4, 4
; GFX9-NEXT:    s_addc_u32 s5, s5, 0
; GFX9-NEXT:    v_add_u32_e32 v5, s2, v4
; GFX9-NEXT:    v_cndmask_b32_e32 v3, v4, v3, vcc
; GFX9-NEXT:    v_cndmask_b32_e64 v3, v5, v3, s[0:1]
; GFX9-NEXT:    s_cmpk_eq_i32 s3, 0x400
; GFX9-NEXT:    global_store_dword v[1:2], v3, off
; GFX9-NEXT:    s_cbranch_scc0 BB3_1
; GFX9-NEXT:  ; %bb.2: ; %bb2
; GFX9-NEXT:    s_endpgm
bb:
  br label %bb3

bb2:                                              ; preds = %bb3
  ret void

bb3:                                              ; preds = %bb3, %bb
  %tmp = phi i32 [ 0, %bb ], [ %tmp7, %bb3 ]
  %tmp4 = srem i32 %tmp, %arg1
  %tmp5 = zext i32 %tmp to i64
  %tmp6 = getelementptr inbounds i32, i32 addrspace(1)* %arg, i64 %tmp5
  store i32 %tmp4, i32 addrspace(1)* %tmp6, align 4
  %tmp7 = add nuw nsw i32 %tmp, 1
  %tmp8 = icmp eq i32 %tmp7, 1024
  br i1 %tmp8, label %bb2, label %bb3
}

define amdgpu_kernel void @udiv16_invariant_denom(i16 addrspace(1)* nocapture %arg, i16 %arg1) {
; GFX9-LABEL: udiv16_invariant_denom:
; GFX9:       ; %bb.0: ; %bb
; GFX9-NEXT:    s_load_dword s3, s[0:1], 0x2c
; GFX9-NEXT:    s_mov_b32 s2, 0xffff
; GFX9-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x24
; GFX9-NEXT:    v_mov_b32_e32 v3, 0
; GFX9-NEXT:    v_mov_b32_e32 v4, 0
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    s_and_b32 s3, s2, s3
; GFX9-NEXT:    v_cvt_f32_u32_e32 v0, s3
; GFX9-NEXT:    s_movk_i32 s3, 0x400
; GFX9-NEXT:    v_rcp_iflag_f32_e32 v1, v0
; GFX9-NEXT:  BB4_1: ; %bb3
; GFX9-NEXT:    ; =>This Inner Loop Header: Depth=1
; GFX9-NEXT:    v_and_b32_e32 v2, s2, v4
; GFX9-NEXT:    v_cvt_f32_u32_e32 v8, v2
; GFX9-NEXT:    v_lshlrev_b64 v[5:6], 1, v[2:3]
; GFX9-NEXT:    v_mov_b32_e32 v7, s5
; GFX9-NEXT:    v_add_co_u32_e64 v5, s[0:1], s4, v5
; GFX9-NEXT:    v_mul_f32_e32 v2, v8, v1
; GFX9-NEXT:    v_trunc_f32_e32 v2, v2
; GFX9-NEXT:    v_addc_co_u32_e64 v6, s[0:1], v7, v6, s[0:1]
; GFX9-NEXT:    v_cvt_u32_f32_e32 v7, v2
; GFX9-NEXT:    v_add_u16_e32 v4, 1, v4
; GFX9-NEXT:    v_mad_f32 v2, -v2, v0, v8
; GFX9-NEXT:    v_cmp_ge_f32_e64 s[0:1], |v2|, v0
; GFX9-NEXT:    v_cmp_eq_u16_e32 vcc, s3, v4
; GFX9-NEXT:    v_addc_co_u32_e64 v2, s[0:1], 0, v7, s[0:1]
; GFX9-NEXT:    s_and_b64 vcc, exec, vcc
; GFX9-NEXT:    global_store_short v[5:6], v2, off
; GFX9-NEXT:    s_cbranch_vccz BB4_1
; GFX9-NEXT:  ; %bb.2: ; %bb2
; GFX9-NEXT:    s_endpgm
bb:
  br label %bb3

bb2:                                              ; preds = %bb3
  ret void

bb3:                                              ; preds = %bb3, %bb
  %tmp = phi i16 [ 0, %bb ], [ %tmp7, %bb3 ]
  %tmp4 = udiv i16 %tmp, %arg1
  %tmp5 = zext i16 %tmp to i64
  %tmp6 = getelementptr inbounds i16, i16 addrspace(1)* %arg, i64 %tmp5
  store i16 %tmp4, i16 addrspace(1)* %tmp6, align 2
  %tmp7 = add nuw nsw i16 %tmp, 1
  %tmp8 = icmp eq i16 %tmp7, 1024
  br i1 %tmp8, label %bb2, label %bb3
}

define amdgpu_kernel void @urem16_invariant_denom(i16 addrspace(1)* nocapture %arg, i16 %arg1) {
; GFX9-LABEL: urem16_invariant_denom:
; GFX9:       ; %bb.0: ; %bb
; GFX9-NEXT:    s_load_dword s3, s[0:1], 0x2c
; GFX9-NEXT:    s_mov_b32 s2, 0xffff
; GFX9-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x24
; GFX9-NEXT:    v_mov_b32_e32 v3, 0
; GFX9-NEXT:    s_movk_i32 s6, 0x400
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    s_and_b32 s3, s2, s3
; GFX9-NEXT:    v_cvt_f32_u32_e32 v0, s3
; GFX9-NEXT:    v_mov_b32_e32 v4, 0
; GFX9-NEXT:    v_rcp_iflag_f32_e32 v1, v0
; GFX9-NEXT:  BB5_1: ; %bb3
; GFX9-NEXT:    ; =>This Inner Loop Header: Depth=1
; GFX9-NEXT:    v_and_b32_e32 v2, s2, v4
; GFX9-NEXT:    v_cvt_f32_u32_e32 v8, v2
; GFX9-NEXT:    v_lshlrev_b64 v[5:6], 1, v[2:3]
; GFX9-NEXT:    v_mov_b32_e32 v7, s5
; GFX9-NEXT:    v_add_co_u32_e64 v5, s[0:1], s4, v5
; GFX9-NEXT:    v_addc_co_u32_e64 v6, s[0:1], v7, v6, s[0:1]
; GFX9-NEXT:    v_mul_f32_e32 v7, v8, v1
; GFX9-NEXT:    v_trunc_f32_e32 v7, v7
; GFX9-NEXT:    v_cvt_u32_f32_e32 v9, v7
; GFX9-NEXT:    v_mad_f32 v7, -v7, v0, v8
; GFX9-NEXT:    v_cmp_ge_f32_e64 s[0:1], |v7|, v0
; GFX9-NEXT:    v_add_u16_e32 v4, 1, v4
; GFX9-NEXT:    v_addc_co_u32_e64 v7, s[0:1], 0, v9, s[0:1]
; GFX9-NEXT:    v_mul_lo_u32 v7, v7, s3
; GFX9-NEXT:    v_cmp_eq_u16_e32 vcc, s6, v4
; GFX9-NEXT:    s_and_b64 vcc, exec, vcc
; GFX9-NEXT:    v_sub_u32_e32 v2, v2, v7
; GFX9-NEXT:    global_store_short v[5:6], v2, off
; GFX9-NEXT:    s_cbranch_vccz BB5_1
; GFX9-NEXT:  ; %bb.2: ; %bb2
; GFX9-NEXT:    s_endpgm
bb:
  br label %bb3

bb2:                                              ; preds = %bb3
  ret void

bb3:                                              ; preds = %bb3, %bb
  %tmp = phi i16 [ 0, %bb ], [ %tmp7, %bb3 ]
  %tmp4 = urem i16 %tmp, %arg1
  %tmp5 = zext i16 %tmp to i64
  %tmp6 = getelementptr inbounds i16, i16 addrspace(1)* %arg, i64 %tmp5
  store i16 %tmp4, i16 addrspace(1)* %tmp6, align 2
  %tmp7 = add nuw nsw i16 %tmp, 1
  %tmp8 = icmp eq i16 %tmp7, 1024
  br i1 %tmp8, label %bb2, label %bb3
}

define amdgpu_kernel void @sdiv16_invariant_denom(i16 addrspace(1)* nocapture %arg, i16 %arg1) {
; GFX9-LABEL: sdiv16_invariant_denom:
; GFX9:       ; %bb.0: ; %bb
; GFX9-NEXT:    s_load_dword s2, s[0:1], 0x2c
; GFX9-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x24
; GFX9-NEXT:    v_mov_b32_e32 v3, 0
; GFX9-NEXT:    s_movk_i32 s3, 0x400
; GFX9-NEXT:    v_mov_b32_e32 v4, 0
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    s_sext_i32_i16 s2, s2
; GFX9-NEXT:    v_cvt_f32_i32_e32 v0, s2
; GFX9-NEXT:    v_rcp_iflag_f32_e32 v1, v0
; GFX9-NEXT:  BB6_1: ; %bb3
; GFX9-NEXT:    ; =>This Inner Loop Header: Depth=1
; GFX9-NEXT:    v_bfe_i32 v5, v4, 0, 16
; GFX9-NEXT:    v_and_b32_e32 v2, 0xffff, v4
; GFX9-NEXT:    v_cvt_f32_i32_e32 v9, v5
; GFX9-NEXT:    v_xor_b32_e32 v8, s2, v5
; GFX9-NEXT:    v_lshlrev_b64 v[5:6], 1, v[2:3]
; GFX9-NEXT:    v_mov_b32_e32 v7, s5
; GFX9-NEXT:    v_add_co_u32_e64 v5, s[0:1], s4, v5
; GFX9-NEXT:    v_addc_co_u32_e64 v6, s[0:1], v7, v6, s[0:1]
; GFX9-NEXT:    v_mul_f32_e32 v7, v9, v1
; GFX9-NEXT:    v_trunc_f32_e32 v7, v7
; GFX9-NEXT:    v_ashrrev_i32_e32 v2, 30, v8
; GFX9-NEXT:    v_cvt_i32_f32_e32 v8, v7
; GFX9-NEXT:    v_mad_f32 v7, -v7, v0, v9
; GFX9-NEXT:    v_add_u16_e32 v4, 1, v4
; GFX9-NEXT:    v_or_b32_e32 v2, 1, v2
; GFX9-NEXT:    v_cmp_ge_f32_e64 s[0:1], |v7|, |v0|
; GFX9-NEXT:    v_cmp_eq_u16_e32 vcc, s3, v4
; GFX9-NEXT:    v_cndmask_b32_e64 v2, 0, v2, s[0:1]
; GFX9-NEXT:    v_add_u32_e32 v2, v8, v2
; GFX9-NEXT:    s_and_b64 vcc, exec, vcc
; GFX9-NEXT:    global_store_short v[5:6], v2, off
; GFX9-NEXT:    s_cbranch_vccz BB6_1
; GFX9-NEXT:  ; %bb.2: ; %bb2
; GFX9-NEXT:    s_endpgm
bb:
  br label %bb3

bb2:                                              ; preds = %bb3
  ret void

bb3:                                              ; preds = %bb3, %bb
  %tmp = phi i16 [ 0, %bb ], [ %tmp7, %bb3 ]
  %tmp4 = sdiv i16 %tmp, %arg1
  %tmp5 = zext i16 %tmp to i64
  %tmp6 = getelementptr inbounds i16, i16 addrspace(1)* %arg, i64 %tmp5
  store i16 %tmp4, i16 addrspace(1)* %tmp6, align 2
  %tmp7 = add nuw nsw i16 %tmp, 1
  %tmp8 = icmp eq i16 %tmp7, 1024
  br i1 %tmp8, label %bb2, label %bb3
}

define amdgpu_kernel void @srem16_invariant_denom(i16 addrspace(1)* nocapture %arg, i16 %arg1) {
; GFX9-LABEL: srem16_invariant_denom:
; GFX9:       ; %bb.0: ; %bb
; GFX9-NEXT:    s_load_dword s2, s[0:1], 0x2c
; GFX9-NEXT:    s_load_dwordx2 s[4:5], s[0:1], 0x24
; GFX9-NEXT:    v_mov_b32_e32 v3, 0
; GFX9-NEXT:    s_movk_i32 s3, 0x400
; GFX9-NEXT:    v_mov_b32_e32 v4, 0
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    s_sext_i32_i16 s2, s2
; GFX9-NEXT:    v_cvt_f32_i32_e32 v0, s2
; GFX9-NEXT:    v_rcp_iflag_f32_e32 v1, v0
; GFX9-NEXT:  BB7_1: ; %bb3
; GFX9-NEXT:    ; =>This Inner Loop Header: Depth=1
; GFX9-NEXT:    v_bfe_i32 v7, v4, 0, 16
; GFX9-NEXT:    v_and_b32_e32 v2, 0xffff, v4
; GFX9-NEXT:    v_cvt_f32_i32_e32 v10, v7
; GFX9-NEXT:    v_lshlrev_b64 v[5:6], 1, v[2:3]
; GFX9-NEXT:    v_mov_b32_e32 v8, s5
; GFX9-NEXT:    v_add_co_u32_e64 v5, s[0:1], s4, v5
; GFX9-NEXT:    v_addc_co_u32_e64 v6, s[0:1], v8, v6, s[0:1]
; GFX9-NEXT:    v_mul_f32_e32 v8, v10, v1
; GFX9-NEXT:    v_xor_b32_e32 v9, s2, v7
; GFX9-NEXT:    v_trunc_f32_e32 v8, v8
; GFX9-NEXT:    v_ashrrev_i32_e32 v2, 30, v9
; GFX9-NEXT:    v_cvt_i32_f32_e32 v9, v8
; GFX9-NEXT:    v_mad_f32 v8, -v8, v0, v10
; GFX9-NEXT:    v_or_b32_e32 v2, 1, v2
; GFX9-NEXT:    v_cmp_ge_f32_e64 s[0:1], |v8|, |v0|
; GFX9-NEXT:    v_cndmask_b32_e64 v2, 0, v2, s[0:1]
; GFX9-NEXT:    v_add_u32_e32 v2, v9, v2
; GFX9-NEXT:    v_mul_lo_u32 v2, v2, s2
; GFX9-NEXT:    v_add_u16_e32 v4, 1, v4
; GFX9-NEXT:    v_cmp_eq_u16_e32 vcc, s3, v4
; GFX9-NEXT:    s_and_b64 vcc, exec, vcc
; GFX9-NEXT:    v_sub_u32_e32 v2, v7, v2
; GFX9-NEXT:    global_store_short v[5:6], v2, off
; GFX9-NEXT:    s_cbranch_vccz BB7_1
; GFX9-NEXT:  ; %bb.2: ; %bb2
; GFX9-NEXT:    s_endpgm
bb:
  br label %bb3

bb2:                                              ; preds = %bb3
  ret void

bb3:                                              ; preds = %bb3, %bb
  %tmp = phi i16 [ 0, %bb ], [ %tmp7, %bb3 ]
  %tmp4 = srem i16 %tmp, %arg1
  %tmp5 = zext i16 %tmp to i64
  %tmp6 = getelementptr inbounds i16, i16 addrspace(1)* %arg, i64 %tmp5
  store i16 %tmp4, i16 addrspace(1)* %tmp6, align 2
  %tmp7 = add nuw nsw i16 %tmp, 1
  %tmp8 = icmp eq i16 %tmp7, 1024
  br i1 %tmp8, label %bb2, label %bb3
}
