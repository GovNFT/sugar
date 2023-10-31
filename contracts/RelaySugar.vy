# SPDX-License-Identifier: BUSL-1.1
# @version >=0.3.6 <0.4.0

# @title Velodrome Finance Relay Sugar v2
# @author stas, ZoomerAnon
# @notice Makes it nicer to work with Relay.

MAX_RELAYS: constant(uint256) = 50
MAX_RESULTS: constant(uint256) = 1000
MAX_PAIRS: constant(uint256) = 30
WEEK: constant(uint256) = 7 * 24 * 60 * 60

struct LpVotes:
  lp: address
  weight: uint256

struct Relay:
  venft_id: uint256
  decimals: uint8
  amount: uint128
  voting_amount: uint256
  used_voting_amount: uint256
  voted_at: uint256
  votes: DynArray[LpVotes, MAX_PAIRS]
  token: address
  compounded: uint256
  withdrawable: uint256
  run_at: uint256
  manager: address
  relay: address
  inactive: bool
  name: String[100]
  account_venft_ids: DynArray[uint256, MAX_RESULTS]


interface IERC20:
  def balanceOf(_account: address) -> uint256: view

interface IVoter:
  def ve() -> address: view
  def lastVoted(_venft_id: uint256) -> uint256: view
  def poolVote(_venft_id: uint256, _index: uint256) -> address: view
  def votes(_venft_id: uint256, _lp: address) -> uint256: view
  def usedWeights(_venft_id: uint256) -> uint256: view

interface IVotingEscrow:
  def idToManaged(_venft_id: uint256) -> uint256: view
  def deactivated(_venft_id: uint256) -> bool: view
  def token() -> address: view
  def decimals() -> uint8: view
  def ownerOf(_venft_id: uint256) -> address: view
  def balanceOfNFT(_venft_id: uint256) -> uint256: view
  def locked(_venft_id: uint256) -> (uint128, uint256, bool): view
  def ownerToNFTokenIdList(_account: address, _index: uint256) -> uint256: view
  def voted(_venft_id: uint256) -> bool: view

interface IRelayRegistry:
  def getAll() -> DynArray[address, MAX_RELAYS]: view

interface IRelayFactory:
  def relays() -> DynArray[address, MAX_RELAYS]: view

interface IRelay:
  def name() -> String[100]: view
  def mTokenId() -> uint256: view
  def token() -> address: view
  def keeperLastRun() -> uint256: view
  # Latest epoch rewards
  def amountTokenEarned(_epoch_ts: uint256) -> uint256: view
  def DEFAULT_ADMIN_ROLE() -> bytes32: view
  def getRoleMember(_role: bytes32, _index: uint256) -> address: view

# Vars
registry: public(IRelayRegistry)
voter: public(IVoter)
ve: public(IVotingEscrow)
token: public(address)

@external
def __init__(_registry: address, _voter: address):
  """
  @dev Set up our external registry and voter contracts
  """
  self.registry = IRelayRegistry(_registry)
  self.voter = IVoter(_voter)
  self.ve = IVotingEscrow(self.voter.ve())
  self.token = self.ve.token()

@external
@view
def all(_account: address) -> DynArray[Relay, MAX_RELAYS]:
  """
  @notice Returns all Relays and account's deposits
  @return Array of Relay structs
  """
  return self._relays(_account)

@internal
@view
def _relays(_account: address) -> DynArray[Relay, MAX_RELAYS]:
  """
  @notice Returns all Relays and account's deposits
  @return Array of Relay structs
  """
  relays: DynArray[Relay, MAX_RELAYS] = empty(DynArray[Relay, MAX_RELAYS])
  factories: DynArray[address, MAX_RELAYS] = self.registry.getAll()

  for factory_index in range(0, MAX_RELAYS):
    if factory_index == len(factories):
      break

    relay_factory: IRelayFactory = IRelayFactory(factories[factory_index])
    addresses: DynArray[address, MAX_RELAYS] = relay_factory.relays()

    for index in range(0, MAX_RELAYS):
      if index == len(addresses):
        break

      relay: Relay = self._byAddress(addresses[index], _account)
      relays.append(relay)

  return relays

@internal
@view
def _byAddress(_relay: address, _account: address) -> Relay:
  """
  @notice Returns Relay data based on address, with optional account arg
  @param _relay The Relay address to lookup
  @param _account The account address to lookup deposits
  @return Relay struct
  """
  
  relay: IRelay = IRelay(_relay)
  managed_id: uint256 = relay.mTokenId()

  account_venft_ids: DynArray[uint256, MAX_RESULTS] = empty(DynArray[uint256, MAX_RESULTS])

  for venft_index in range(MAX_RESULTS):
    account_venft_id: uint256 = self.ve.ownerToNFTokenIdList(_account, venft_index)

    if account_venft_id == 0:
      break
    
    account_venft_manager_id: uint256 = self.ve.idToManaged(account_venft_id)
    if account_venft_manager_id == managed_id:
      account_venft_ids.append(account_venft_id)

  votes: DynArray[LpVotes, MAX_PAIRS] = []
  amount: uint128 = self.ve.locked(managed_id)[0]
  last_voted: uint256 = 0
  withdrawable: uint256 = 0
  inactive: bool = self.ve.deactivated(managed_id)

  admin_role: bytes32 = relay.DEFAULT_ADMIN_ROLE()
  manager: address = relay.getRoleMember(admin_role, 0)

  # If the Relay is an AutoConverter, fetch withdrawable amount
  if self.token != relay.token():
    token: IERC20 = IERC20(relay.token())
    withdrawable = token.balanceOf(_relay)

  epoch_start_ts: uint256 = block.timestamp / WEEK * WEEK

  # Rewards claimed this epoch
  rewards_compounded: uint256 = relay.amountTokenEarned(epoch_start_ts)

  if self.ve.voted(managed_id):
    last_voted = self.voter.lastVoted(managed_id)

  vote_weight: uint256 = self.voter.usedWeights(managed_id)
  # Since we don't have a way to see how many pools the veNFT voted...
  left_weight: uint256 = vote_weight

  for index in range(MAX_PAIRS):
    if left_weight == 0:
      break

    lp: address = self.voter.poolVote(managed_id, index)

    if lp == empty(address):
      break

    weight: uint256 = self.voter.votes(managed_id, lp)

    votes.append(LpVotes({
      lp: lp,
      weight: weight
    }))

    # Remove _counted_ weight to see if there are other pool votes left...
    left_weight -= weight

  return Relay({
    venft_id: managed_id,
    decimals: self.ve.decimals(),
    amount: amount,
    voting_amount: self.ve.balanceOfNFT(managed_id),
    used_voting_amount: vote_weight,
    voted_at: last_voted,
    votes: votes,
    token: relay.token(),
    compounded: rewards_compounded,
    withdrawable: withdrawable,
    run_at: relay.keeperLastRun(),
    manager: manager,
    relay: _relay,
    inactive: inactive,
    name: relay.name(),
    account_venft_ids: account_venft_ids
  })
