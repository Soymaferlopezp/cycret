// src/merkle.cairo
//
// Incremental Merkle Tree (depth=10) using Pedersen hash.
// - Capacity = 2^10 = 1024 leaves
// - zeros derived in-code (no storage)
// - leaf used as-is (commitment felt252), no re-hash
//
// API:
//   initial_filled_subtrees() -> Array<felt252> (len=10)
//   insert_leaf(index, leaf, filled) -> (new_root, new_filled)
//     - reverts if index >= 1024

use core::array::ArrayTrait;
use core::hash::HashStateTrait;
use core::pedersen::PedersenTrait;

pub const DEPTH_U32: u32 = 10_u32;
pub const CAPACITY: u32 = 1024_u32;

fn pedersen2(left: felt252, right: felt252) -> felt252 {
    PedersenTrait::new(0).update(left).update(right).finalize()
}

// zeros[0] = 0
// zeros[i+1] = pedersen2(zeros[i], zeros[i]) for i in 0..9
fn build_zeros() -> Array<felt252> {
    let mut zeros: Array<felt252> = ArrayTrait::new();
    zeros.append(0);

    let mut i: u32 = 0_u32;
    loop {
        if i == DEPTH_U32 {
            break;
        }

        let idx: usize = match i {
            0_u32 => 0_usize,
            1_u32 => 1_usize,
            2_u32 => 2_usize,
            3_u32 => 3_usize,
            4_u32 => 4_usize,
            5_u32 => 5_usize,
            6_u32 => 6_usize,
            7_u32 => 7_usize,
            8_u32 => 8_usize,
            _ => 9_usize,
        };

        let z: felt252 = *zeros.at(idx);
        let next = pedersen2(z, z);
        zeros.append(next);

        i += 1_u32;
    };

    zeros
}

// initial filled_subtrees[i] = zeros[i] for i in 0..9
pub fn initial_filled_subtrees() -> Array<felt252> {
    let zeros = build_zeros();
    let mut filled: Array<felt252> = ArrayTrait::new();

    filled.append(*zeros.at(0_usize));
    filled.append(*zeros.at(1_usize));
    filled.append(*zeros.at(2_usize));
    filled.append(*zeros.at(3_usize));
    filled.append(*zeros.at(4_usize));
    filled.append(*zeros.at(5_usize));
    filled.append(*zeros.at(6_usize));
    filled.append(*zeros.at(7_usize));
    filled.append(*zeros.at(8_usize));
    filled.append(*zeros.at(9_usize));

    filled
}

// Rebuild filled array with filled[pos] = val (len is always 10 so explicit is fine)
fn set_filled_at(filled: Array<felt252>, pos: u32, val: felt252) -> Array<felt252> {
    let a0: felt252 = *filled.at(0_usize);
    let a1: felt252 = *filled.at(1_usize);
    let a2: felt252 = *filled.at(2_usize);
    let a3: felt252 = *filled.at(3_usize);
    let a4: felt252 = *filled.at(4_usize);
    let a5: felt252 = *filled.at(5_usize);
    let a6: felt252 = *filled.at(6_usize);
    let a7: felt252 = *filled.at(7_usize);
    let a8: felt252 = *filled.at(8_usize);
    let a9: felt252 = *filled.at(9_usize);

    let mut out: Array<felt252> = ArrayTrait::new();

    out.append(if pos == 0_u32 { val } else { a0 });
    out.append(if pos == 1_u32 { val } else { a1 });
    out.append(if pos == 2_u32 { val } else { a2 });
    out.append(if pos == 3_u32 { val } else { a3 });
    out.append(if pos == 4_u32 { val } else { a4 });
    out.append(if pos == 5_u32 { val } else { a5 });
    out.append(if pos == 6_u32 { val } else { a6 });
    out.append(if pos == 7_u32 { val } else { a7 });
    out.append(if pos == 8_u32 { val } else { a8 });
    out.append(if pos == 9_u32 { val } else { a9 });

    out
}

pub fn insert_leaf(
    index: u32,
    leaf: felt252,
    mut filled_subtrees: Array<felt252>,
) -> (felt252, Array<felt252>) {
    if index >= CAPACITY {
        panic!("TREE_FULL");
    }

    if filled_subtrees.len() != 10_usize {
        panic!("BAD_FILLED_LEN");
    }

    let zeros = build_zeros();

    let mut cur: felt252 = leaf;
    let mut idx: u32 = index;

    let mut level: u32 = 0_u32;
    loop {
        if level == DEPTH_U32 {
            break;
        }

        let li: usize = match level {
            0_u32 => 0_usize,
            1_u32 => 1_usize,
            2_u32 => 2_usize,
            3_u32 => 3_usize,
            4_u32 => 4_usize,
            5_u32 => 5_usize,
            6_u32 => 6_usize,
            7_u32 => 7_usize,
            8_u32 => 8_usize,
            _ => 9_usize,
        };

        let is_right = (idx & 1_u32) == 1_u32;

        if !is_right {
            let left: felt252 = cur;
            let right: felt252 = *zeros.at(li);

            filled_subtrees = set_filled_at(filled_subtrees, level, cur);
            cur = pedersen2(left, right);
        } else {
            let left: felt252 = *filled_subtrees.at(li);
            let right: felt252 = cur;

            cur = pedersen2(left, right);
        }

        idx = idx / 2_u32;
        level += 1_u32;
    };

    (cur, filled_subtrees)
}
