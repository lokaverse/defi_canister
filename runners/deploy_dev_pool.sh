dfx identity use lokaDeployer
dfx deploy devpool --argument '(record{admin = principal "mtyh3-temyy-tmbjp-ftvuq-4fn46-do3rx-kpkmx-sghhf-pfvs7-5viz5-nae"})' --network ic
dfx canister call devpool init '(false)' --network ic;
dfx canister call devpool enableDistribution '(true)' --network ic;