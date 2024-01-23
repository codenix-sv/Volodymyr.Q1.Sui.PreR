import { getFullnodeUrl, SuiClient } from '@mysten/sui.js/client';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { TransactionBlock } from '@mysten/sui.js/transactions';

import wallet from './dev-wallet.json';

// Import our dev wallet keypair from the wallet file
const keypair = Ed25519Keypair.fromSecretKey(new Uint8Array(wallet));

// Define our WBA SUI Address
const to = '0x09ed82ad567fd6a0abeda80b3072b16cc818e6260149bce7692bd22af6a0155b';

const client = new SuiClient({ url: getFullnodeUrl('devnet') });

(async () => {
	try {
		//create Transaction Block.
		const txb = new TransactionBlock();
		//Add a transferObject transaction
		txb.transferObjects([txb.gas], to);
		let txid = await client.signAndExecuteTransactionBlock({ signer: keypair, transactionBlock: txb });
		console.log(`Success! Check our your TX here:
        https://suiexplorer.com/txblock/${txid.digest}?network=testnet`);
	} catch (e) {
		console.error(`Oops, something went wrong: ${e}`);
	}
})();
