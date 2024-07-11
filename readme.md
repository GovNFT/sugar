# GovNFT Sugar 🍭

Sugar comes with contracts to help working with GovNFT data!

## How come?!

Instead of relying on an API for GovNFT data, these contracts
can be called in an efficient way to directly fetch the same data
off-chain.

Main goals of this little project are:
  * to maximize the developers UX of working with GovNFT
  * simplify complexity
  * document and test everything

## But how?

On-chain data is organized for transaction cost and efficiency. We think
we can hide a lot of the complexity by leveraging `structs` to present the data
and normalize it based on it's relevancy.

## Usage

Below is the list of data we support.

### GovNFT Data

`GovNFTSugar.vy` is deployed at `0xB3e2C137A3a6f680A0D1f78DaA563689A61d7f80`

It allows fetching GovNFT data.
The returned data/struct of type `GovNft` values represent:

  * `id` - token ID of the GovNFT
  * `total_locked` - total locked amount of the GovNFT at creation
  * `amount` - current locked amount of the GovNFT
  * `total_claimed` - amount of total tokens claimed by the owner
  * `claimable` - current amount of tokens that are vested and claimable
  * `split_count` - number of times the GovNFT has been split
  * `cliff_length` - the length of the vesting cliff, in seconds
  * `start` - timestamp of when vesting begins
  * `end` - timestamp of when vesting ends
  * `token` - the underlying vesting ERC20 token of the GovNFT
  * `vault` - the vault address of the GovNFT
  * `minter` - the address of the creator of the GovNFT
  * `owner` - the owner of the GovNFT
  * `address` - the address of the GovNFT collection
  * `delegated` - the address that the underlying ERC20 token of the GovNFT is being delegated to

The returned data/struct of type `Collection` values represent:

  * `address` - address of the GovNFT collection
  * `owner` - owner admin of the GovNFT collection contract
  * `name` - name of the GovNFT collection
  * `symbol` - symbol of the GovNFT collection
  * `supply` - total number of GovNFTs in the collection

---

The available methods are:
 * `collections() -> Collection[]` - returns a list of all GovNFT `Collection` structs that have been created by the factory.
 * `owned(_account: address, _collection: address) -> GovNft[]` - returns a list of all `GovNft` structs owned by the given account for the given collection.
 * `minted(_account: address, _collection: address) -> GovNft[]` - returns a list of all `GovNft` structs minted by the given account for the given collection.
 * `byId(_govnft_id: uint256, _collection: address) -> GovNft` - returns the `GovNft` based on the given ID and collection.

## Development

To setup the environment, build the Docker image first:
```sh
docker build ./ -t govnft/sugar
```

Next start the container with existing environment variables:
```sh
docker run --env-file=env.example --rm -v $(pwd):/app -w /app -it govnft/sugar sh
```
The environment has Brownie and Vyper already installed.

To run the tests inside the container, use:
```sh
brownie test --network=optimism-test
```

## Why the contracts are not verified?

Sugar is written in Vyper, and Optimistic Etherscan fails at times to
generate the same bytecode (probably because of the hardcoded `evm_version`).

## How to generate the constructor arguments for verification?

Consider using the web tool at https://abi.hashex.org to build the arguments
and provide the generated value as part of the Etherscan verification form.
