# proposal-tracker

Repo that allows to track voting status of "tallies" which are group of neurons defined by users. To do so this service periodically fetches proposal data from a governance canister (i.e NNS or SNS) and updates the tallies status by fetching the most up to date neurons ballots. The service is based on a pub-sub model, each tally can be subscribed to by a client (i.e a separate canister). An Open chat bot has been developed to make it easy for users to subscribe to tallies, it can be found [here](https://github.com/AleDema/OC-Sample-Bot)

## Running the project locally

If you want to test your project locally, you can use the following commands:

```bash
# Starts the replica, running in the background
dfx start --background
# Install Mops
curl -fsSL cli.mops.one/install.sh | sh
# Init mops
mops init
# Install mops packages
mops install
# Deploys your canisters to the replica and generates your candid interface
dfx deploy
```

Once the job completes, your application will be available at `http://localhost:4943?canisterId={asset_canister_id}`.

If you have made changes to your backend canister, you can generate a new candid interface with

```bash
npm run generate
```

## Usage
Once the canister has been deployed on mainnet, it can be interacted with either by using DFX or Candid UI, if you wish to use the latter, it is first required that the principal si added to the admin list, otherwise management endpoints will not be available.
To do so, use the following command:

  ```bash
  dfx canister call proposal_tracker_backend addCustodian '(principal "${your-principal}")' --ic
  ```

### Adding tallies
To add new tallies, the following command can be used:

  ```bash
  dfx canister call proposal_tracker_backend addTally '(record {
    governanceId = "your_governance_id";
    alias = opt "Your Alias";
    topics = vec { 1,2,3 };
    neurons = vec { "neuron1" };
    subscriber = opt (principal "2vxsx-fae")
})' --ic
  ```

### Initiating timer
In order to periodically receive tally updates, it is required to initiate a timer, it is possible to specify the interval in seconds, if not provided the default value is 5 minutes.
  ```bash
  dfx canister call proposal_tracker_backend initTimer '(opt 60)'
  ```

### Clearing timer
Once initiated the timer is preserved across upgrades, if you wish to clear it for maintenance purposes or to update the interval, the following command can be used:
  ```bash
  dfx canister call proposal_tracker_backend clearTimer
  ```

### Getting tally information
To get the basic information about a tally, such as its alias, neurons and followed topics, the following command can be used:
  ```bash
  dfx canister call proposal_tracker_backend getTally '("your_tally_id")'
  ```
### Deleting a tally
To delete a tally, the following command can be used:
  ```bash
  dfx canister call proposal_tracker_backend deleteTally '("your_tally_id")'
  ```
### Updating a tally
To update a tally, the following command can be used:
  ```bash
  dfx canister call proposal_tracker_backend updateTally '("your_tally_id", 
  record {
    topics = vec { 1; 2; 3 };
    neurons = vec { "neuron1"; "neuron2" }
  }
)'
  ```