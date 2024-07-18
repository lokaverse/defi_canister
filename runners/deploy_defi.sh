dfx identity use lokaDeployer

sudo dfx deploy defi --argument '(record{admin = principal "mtyh3-temyy-tmbjp-ftvuq-4fn46-do3rx-kpkmx-sghhf-pfvs7-5viz5-nae"})' --network ic

sudo dfx canister call defi init --network ic
