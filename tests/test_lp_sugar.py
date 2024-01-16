# SPDX-License-Identifier: BUSL-1.1
import os
import pytest
from collections import namedtuple

from web3.constants import ADDRESS_ZERO


@pytest.fixture
def sugar_contract(LpSugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield LpSugar.at(os.getenv('LP_SUGAR_ADDRESS'))


@pytest.fixture
def TokenStruct(sugar_contract):
    method_output = sugar_contract.tokens.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('TokenStruct', members)


@pytest.fixture
def LpStruct(sugar_contract):
    method_output = sugar_contract.byIndex.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('LpStruct', members)


@pytest.fixture
def SwapLpStruct(sugar_contract):
    method_output = sugar_contract.forSwaps.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('SwapLpStruct', members)


@pytest.fixture
def LpEpochStruct(sugar_contract):
    method_output = sugar_contract.epochsByAddress.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('LpEpochStruct', members)


@pytest.fixture
def LpEpochBribeStruct(sugar_contract):
    lp_epoch_comp = sugar_contract.epochsByAddress.abi['outputs'][0]
    pe_bribe_comp = lp_epoch_comp['components'][4]
    members = list(map(lambda _e: _e['name'], pe_bribe_comp['components']))

    yield namedtuple('LpEpochBribeStruct', members)


def test_initial_state(sugar_contract):
    assert sugar_contract.voter() == os.getenv('VOTER_ADDRESS')
    assert sugar_contract.registry() == os.getenv('REGISTRY_ADDRESS')
    assert sugar_contract.router() is not None


def test_byIndex(sugar_contract, LpStruct):
    lp = LpStruct(*sugar_contract.byIndex(0, ADDRESS_ZERO))

    assert lp is not None
    assert len(lp) == 28
    assert lp.lp is not None
    assert lp.gauge != ADDRESS_ZERO


def test_forSwaps(sugar_contract, SwapLpStruct, LpStruct):
    first_lp = LpStruct(*sugar_contract.byIndex(0, ADDRESS_ZERO))
    second_lp = LpStruct(*sugar_contract.byIndex(1, ADDRESS_ZERO))
    swap_lps = list(map(
        lambda _p: SwapLpStruct(*_p),
        sugar_contract.forSwaps(10, 0)
    ))

    assert swap_lps is not None
    assert len(swap_lps) > 1

    lp1, lp2 = swap_lps[0:2]

    assert lp1.lp == first_lp.lp

    assert lp2.lp == second_lp.lp


def test_tokens(sugar_contract, TokenStruct, LpStruct):
    first_lp = LpStruct(*sugar_contract.byIndex(0, ADDRESS_ZERO))
    second_lp = LpStruct(*sugar_contract.byIndex(1, ADDRESS_ZERO))
    tokens = list(map(
        lambda _p: TokenStruct(*_p),
        sugar_contract.tokens(10, 0, ADDRESS_ZERO, [])
    ))

    assert tokens is not None
    assert len(tokens) > 1

    token0, token1, token2 = tokens[0: 3]

    assert token0.token_address == first_lp.token0
    assert token0.symbol is not None
    assert token0.decimals > 0

    assert token1.token_address == first_lp.token1
    assert token2.token_address == second_lp.token0


def test_all(sugar_contract, LpStruct):
    first_lp = LpStruct(*sugar_contract.byIndex(0, ADDRESS_ZERO))
    second_lp = LpStruct(*sugar_contract.byIndex(1, ADDRESS_ZERO))
    lps = list(map(
        lambda _p: LpStruct(*_p),
        sugar_contract.all(10, 0, ADDRESS_ZERO)
    ))

    assert lps is not None
    assert len(lps) > 1

    lp1, lp2 = lps[0:2]

    assert lp1.lp == first_lp.lp
    assert lp1.gauge == first_lp.gauge

    assert lp2.lp == second_lp.lp
    assert lp2.gauge == second_lp.gauge


def test_all_limit_offset(sugar_contract, LpStruct):
    second_lp = LpStruct(*sugar_contract.byIndex(1, ADDRESS_ZERO))
    lps = list(map(
        lambda _p: LpStruct(*_p),
        sugar_contract.all(1, 1, ADDRESS_ZERO)
    ))

    assert lps is not None
    assert len(lps) == 1

    lp1 = lps[0]

    assert lp1.lp == second_lp.lp
    assert lp1.lp == second_lp.lp


def test_epochsByAddress_limit_offset(
        sugar_contract,
        LpStruct,
        LpEpochStruct,
        LpEpochBribeStruct
        ):
    first_lp = LpStruct(*sugar_contract.byIndex(0, ADDRESS_ZERO))
    lp_epochs = list(map(
        lambda _p: LpEpochStruct(*_p),
        sugar_contract.epochsByAddress(20, 3, first_lp.lp)
    ))

    assert lp_epochs is not None
    assert len(lp_epochs) > 10

    epoch = lp_epochs[1]
    epoch_bribes = list(map(
        lambda _b: LpEpochBribeStruct(*_b),
        epoch.bribes
    ))
    epoch_fees = list(map(
        lambda _f: LpEpochBribeStruct(*_f),
        epoch.fees
    ))

    assert epoch.lp == first_lp.lp
    assert epoch.votes > 0
    assert epoch.emissions > 0

    if len(epoch_bribes) > 0:
        assert epoch_bribes[0].amount > 0

    if len(epoch_fees) > 0:
        assert epoch_fees[0].amount > 0


def test_epochsLatest_limit_offset(
        sugar_contract,
        LpStruct,
        LpEpochStruct
        ):
    second_lp = LpStruct(*sugar_contract.byIndex(1, ADDRESS_ZERO))
    lp_epoch = list(map(
        lambda _p: LpEpochStruct(*_p),
        sugar_contract.epochsByAddress(1, 0, second_lp.lp)
    ))
    latest_epoch = list(map(
        lambda _p: LpEpochStruct(*_p),
        sugar_contract.epochsLatest(1, 1)
    ))

    assert lp_epoch is not None
    assert len(latest_epoch) == 1

    pepoch = LpEpochStruct(*lp_epoch[0])
    lepoch = LpEpochStruct(*latest_epoch[0])

    assert lepoch.lp == pepoch.lp
    assert lepoch.ts == pepoch.ts
