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

fn level_to_usize(level: u32) -> usize {
    match level {
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
    }
}

fn get_filled(level: u32, f0: felt252, f1: felt252, f2: felt252, f3: felt252, f4: felt252, f5: felt252, f6: felt252, f7: felt252, f8: felt252, f9: felt252) -> felt252 {
    match level {
        0_u32 => f0,
        1_u32 => f1,
        2_u32 => f2,
        3_u32 => f3,
        4_u32 => f4,
        5_u32 => f5,
        6_u32 => f6,
        7_u32 => f7,
        8_u32 => f8,
        _ => f9,
    }
}

pub fn insert_leaf(
    index: u32,
    leaf: felt252,
    filled_subtrees: Array<felt252>,
) -> (felt252, Array<felt252>) {
    if index >= CAPACITY {
        panic!("TREE_FULL");
    }

    if filled_subtrees.len() != 10_usize {
        panic!("BAD_FILLED_LEN");
    }

    let zeros = build_zeros();

    // Load filled_subtrees once into locals (optimization)
    let mut f0: felt252 = *filled_subtrees.at(0_usize);
    let mut f1: felt252 = *filled_subtrees.at(1_usize);
    let mut f2: felt252 = *filled_subtrees.at(2_usize);
    let mut f3: felt252 = *filled_subtrees.at(3_usize);
    let mut f4: felt252 = *filled_subtrees.at(4_usize);
    let mut f5: felt252 = *filled_subtrees.at(5_usize);
    let mut f6: felt252 = *filled_subtrees.at(6_usize);
    let mut f7: felt252 = *filled_subtrees.at(7_usize);
    let mut f8: felt252 = *filled_subtrees.at(8_usize);
    let mut f9: felt252 = *filled_subtrees.at(9_usize);

    let mut cur: felt252 = leaf;
    let mut idx: u32 = index;

    let mut level: u32 = 0_u32;
    loop {
        if level == DEPTH_U32 {
            break;
        }

        let is_right = (idx & 1_u32) == 1_u32;
        let li: usize = level_to_usize(level);

        if !is_right {
            // left child: sibling is zeros[level], and we update filled[level] = cur
            let left: felt252 = cur;
            let right: felt252 = *zeros.at(li);

            match level {
                0_u32 => { f0 = cur; },
                1_u32 => { f1 = cur; },
                2_u32 => { f2 = cur; },
                3_u32 => { f3 = cur; },
                4_u32 => { f4 = cur; },
                5_u32 => { f5 = cur; },
                6_u32 => { f6 = cur; },
                7_u32 => { f7 = cur; },
                8_u32 => { f8 = cur; },
                _ => { f9 = cur; },
            };

            cur = pedersen2(left, right);
        } else {
            // right child: sibling is filled[level]
            let left: felt252 = get_filled(level, f0, f1, f2, f3, f4, f5, f6, f7, f8, f9);
            let right: felt252 = cur;

            cur = pedersen2(left, right);
        }

        idx = idx / 2_u32;
        level += 1_u32;
    };

    // Rebuild output array once
    let mut out: Array<felt252> = ArrayTrait::new();
    out.append(f0);
    out.append(f1);
    out.append(f2);
    out.append(f3);
    out.append(f4);
    out.append(f5);
    out.append(f6);
    out.append(f7);
    out.append(f8);
    out.append(f9);

    (cur, out)
}