use contracts::merkle;

#[test]
fn test_insert_3_leaves_deterministic_root() {
    let leaf1: felt252 = 111;
    let leaf2: felt252 = 222;
    let leaf3: felt252 = 333;

    // Run 1
    let filled0 = merkle::initial_filled_subtrees();
    let (r1, filled1) = merkle::insert_leaf(0_u32, leaf1, filled0);
    let (r2, filled2) = merkle::insert_leaf(1_u32, leaf2, filled1);
    let (r3, _filled3) = merkle::insert_leaf(2_u32, leaf3, filled2);

    // Run 2 (same inputs) -> must match
    let filledA = merkle::initial_filled_subtrees();
    let (e1, filledB) = merkle::insert_leaf(0_u32, leaf1, filledA);
    let (e2, filledC) = merkle::insert_leaf(1_u32, leaf2, filledB);
    let (e3, _filledD) = merkle::insert_leaf(2_u32, leaf3, filledC);

    assert(r1 == e1, 'ROOT1_MISMATCH');
    assert(r2 == e2, 'ROOT2_MISMATCH');
    assert(r3 == e3, 'ROOT3_MISMATCH');
}

#[test]
#[should_panic]
fn test_revert_when_index_reaches_capacity() {
    let filled = merkle::initial_filled_subtrees();
    let _ = merkle::insert_leaf(1024_u32, 999, filled);
}
