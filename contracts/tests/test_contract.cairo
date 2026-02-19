use contracts::merkle;

#[test]
fn test_sanity_merkle_module_loaded() {
    let filled = merkle::initial_filled_subtrees();
    assert(filled.len() == 10_usize, 'BAD_LEN');
}
