dfx canister call ckbtc_test icrc1_transfer "(record { to = record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\";};  amount = 1000000000;})" --network ic

dfx canister call defi distributeMPTS '(1000000,"o4k35-i6lb3-mfi6a-6mwzo-iuxj6-qci6k-l7whg-3ntvl-2vcum-dq7ac-2qe")' --network ic

dfx canister call defi distributeLPTS '(1000000)' --network ic