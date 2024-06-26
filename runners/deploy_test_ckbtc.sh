#Deploy the canister


dfx deploy ckbtc_test  --argument "(variant {Init =
record {
     token_symbol = \"CKBTC\";
     token_name = \"CKBTC\";
     minting_account = record { owner = principal \"mtyh3-temyy-tmbjp-ftvuq-4fn46-do3rx-kpkmx-sghhf-pfvs7-5viz5-nae\" };
     transfer_fee = 0;
     metadata = vec {};
     feature_flags = opt record{icrc2 = true};
     initial_balances = vec { record { record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\"; }; 0; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"mtyh3-temyy-tmbjp-ftvuq-4fn46-do3rx-kpkmx-sghhf-pfvs7-5viz5-nae\";
         cycles_for_archive_creation = opt 10000000000000;
     };
 }
})" --network ic


dfx deploy mpts  --argument "(variant {Init =
record {
     token_symbol = \"MPTS\";
     token_name = \"MPTS\";
     minting_account = record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\" };
     transfer_fee = 0;
     metadata = vec {};
     feature_flags = opt record{icrc2 = true};
     initial_balances = vec { record { record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\"; }; 0; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"mtyh3-temyy-tmbjp-ftvuq-4fn46-do3rx-kpkmx-sghhf-pfvs7-5viz5-nae\";
         cycles_for_archive_creation = opt 10000000000000;
     };
 }
})" --network ic

dfx deploy lpts  --argument "(variant {Init =
record {
     token_symbol = \"LPTS\";
     token_name = \"LPTS\";
     minting_account = record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\" };
     transfer_fee = 0;
     metadata = vec {};
     feature_flags = opt record{icrc2 = true};
     initial_balances = vec { record { record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\"; }; 0; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"mtyh3-temyy-tmbjp-ftvuq-4fn46-do3rx-kpkmx-sghhf-pfvs7-5viz5-nae\";
         cycles_for_archive_creation = opt 10000000000000;
     };
 }
})" --network ic



dfx deploy mpts  --argument "(variant {Init =
record {
     token_symbol = \"MPTS\";
     token_name = \"MPTS\";
     minting_account = record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\" };
     transfer_fee = 0;
     metadata = vec {};
     feature_flags = opt record{icrc2 = true};
     initial_balances = vec { record { record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\"; }; 0; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"mtyh3-temyy-tmbjp-ftvuq-4fn46-do3rx-kpkmx-sghhf-pfvs7-5viz5-nae\";
         cycles_for_archive_creation = opt 10000000000000;
     };
 }
})"

dfx deploy lpts  --argument "(variant {Init =
record {
     token_symbol = \"LPTS\";
     token_name = \"LPTS\";
     minting_account = record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\" };
     transfer_fee = 0;
     metadata = vec {};
     feature_flags = opt record{icrc2 = true};
     initial_balances = vec { record { record { owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\"; }; 0; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"mtyh3-temyy-tmbjp-ftvuq-4fn46-do3rx-kpkmx-sghhf-pfvs7-5viz5-nae\";
         cycles_for_archive_creation = opt 10000000000000;
     };
 }
})"



