# @version >=0.3.6 <0.4.0

# @title Velodrome Finance veNFT Sugar v2
# @author stas
# @notice Makes it nicer to work with our vote-escrow NFTs.

MAX_RESULTS: constant(uint256) = 1000
# Basically max gauges for a veNFT, this one is tricky, but
# we can't go crazy with it due to memory limitations...
MAX_PAIRS: constant(uint256) = 30

struct LpVotes:
  lp: address
  weight: uint256

struct VeNFT:
  id: uint256
  account: address
  decimals: uint8
  amount: uint128
  voting_amount: uint256
  rebase_amount: uint256
  expires_at: uint256
  voted_at: uint256
  votes: DynArray[LpVotes, MAX_PAIRS]
  token: address

# Our contracts / Interfaces

interface IVoter:
  def ve() -> address: view
  def gauges(_lp: address) -> address: view
  def gaugeToBribe(_gauge_addr: address) -> address: view
  def gaugeToFees(_gauge_addr: address) -> address: view
  def lastVoted(_venft_id: uint256) -> uint256: view
  def poolVote(_venft_id: uint256, _index: uint256) -> address: view
  def votes(_venft_id: uint256, _lp: address) -> uint256: view
  def usedWeights(_venft_id: uint256) -> uint256: view

interface IRewardsDistributor:
  def ve() -> address: view
  def claimable(_venft_id: uint256) -> uint256: view

interface IVotingEscrow:
  def token() -> address: view
  def decimals() -> uint8: view
  def ownerOf(_venft_id: uint256) -> address: view
  def balanceOfNFT(_venft_id: uint256) -> uint256: view
  def locked(_venft_id: uint256) -> (uint128, uint256): view
  def tokenOfOwnerByIndex(_account: address, _index: uint256) -> uint256: view

# Vars

voter: public(address)
token: public(address)
ve: public(address)
rewards_distributor: public(address)
owner: public(address)

# Methods

@external
def __init__():
  """
  @dev Sets up our contract management address
  """
  self.owner = msg.sender

@external
def setup(_voter: address, _rewards_distributor: address):
  """
  @dev Sets up our external contract addresses
  """
  assert self.owner == msg.sender, 'Not allowed!'

  voter: IVoter = IVoter(_voter)
  rewards_distributor: IRewardsDistributor = \
    IRewardsDistributor(_rewards_distributor)

  assert rewards_distributor.ve() == voter.ve(), 'VE mismatch!'

  self.voter = _voter
  self.ve = voter.ve()
  self.token = IVotingEscrow(self.ve).token()
  self.rewards_distributor = _rewards_distributor

@external
@view
def all(_limit: uint256, _offset: uint256) -> DynArray[VeNFT, MAX_RESULTS]:
  """
  @notice Returns a collection of veNFT data
  @param _limit The max amount of veNFTs to return
  @param _offset The amount of veNFTs to skip
  @return Array for VeNFT structs
  """
  ve: IVotingEscrow = IVotingEscrow(self.ve)
  col: DynArray[VeNFT, MAX_RESULTS] = empty(DynArray[VeNFT, MAX_RESULTS])

  for index in range(_offset, _offset + MAX_RESULTS):
    if len(col) == _limit:
      break

    if ve.ownerOf(index) == empty(address):
      continue

    col.append(self._byId(index))

  return col

@external
@view
def byAccount(_account: address) -> DynArray[VeNFT, MAX_RESULTS]:
  """
  @notice Returns user collection of veNFT data
  @param _account The account address
  @return Array for VeNFT structs
  """
  col: DynArray[VeNFT, MAX_RESULTS] = empty(DynArray[VeNFT, MAX_RESULTS])
  ve: IVotingEscrow = IVotingEscrow(self.ve)

  if _account == empty(address):
    return col

  for index in range(MAX_RESULTS):
    venft_id: uint256 = ve.tokenOfOwnerByIndex(_account, index)

    if venft_id == 0:
      break

    col.append(self._byId(venft_id))

  return col

@external
@view
def byId(_id: uint256) -> VeNFT:
  """
  @notice Returns VeNFT data at a specific stored index
  @param _id The index to lookup
  @return VeNFT struct
  """
  return self._byId(_id)

@internal
@view
def _byId(_id: uint256) -> VeNFT:
  """
  @notice Returns VeNFT data based on the index/ID
  @param _id The index/ID to lookup
  @return VeNFT struct
  """
  ve: IVotingEscrow = IVotingEscrow(self.ve)

  account: address = ve.ownerOf(_id)

  if account == empty(address):
    return empty(VeNFT)

  voter: IVoter = IVoter(self.voter)
  dist: IRewardsDistributor = IRewardsDistributor(self.rewards_distributor)

  votes: DynArray[LpVotes, MAX_PAIRS] = []
  amount: uint128 = 0
  expires_at: uint256 = 0
  amount, expires_at = ve.locked(_id)

  vote_weight: uint256 = voter.usedWeights(_id)
  # Since we don't have a way to see how many pools we voted...
  left_weight: uint256 = vote_weight

  for index in range(MAX_PAIRS):
    if left_weight == 0:
      break

    lp: address = voter.poolVote(_id, index)

    if lp == empty(address):
      break

    weight: uint256 = voter.votes(_id, lp)

    votes.append(LpVotes({
      lp: lp,
      weight: weight
    }))

    # Remove _counted_ weight to see if there are other pool votes left...
    left_weight -= weight

  return VeNFT({
    id: _id,
    account: account,
    decimals: ve.decimals(),

    amount: amount,
    voting_amount: ve.balanceOfNFT(_id),
    rebase_amount: dist.claimable(_id),
    expires_at: expires_at,
    voted_at: voter.lastVoted(_id),
    votes: votes,
    token: self.token,
  })
