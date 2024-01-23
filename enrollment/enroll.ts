import { getFullnodeUrl, SuiClient } from '@mysten/sui.js/client';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { bcs } from '@mysten/sui.js/bcs';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import wallet from '../wba-wallet.json';
import { fromHEX } from '@mysten/sui.js/utils';

const ENROLLMENT_PACKAGE_ID = '0x5927f2574f0a5e2afa574e24bca462269d31cf29bdd2215d908b90b691ea5747';
const COHORT_OBJECT_ID = '0xa85910892fca1bedde91ec6a1379bcf71f4106adbe390ccd67fb696c802d99ab';

const keypair = Ed25519Keypair.fromSecretKey(fromHEX(wallet.privateKey));
const client = new SuiClient({ url: getFullnodeUrl('testnet') });

const github = new Uint8Array(Buffer.from('codenix-sv', 'utf8'));
const txb = new TransactionBlock();
const serializedGithub = txb.pure(bcs.vector(bcs.u8()).serialize(github));

let enroll = txb.moveCall({
	target: `${ENROLLMENT_PACKAGE_ID}::enrollment::enroll`,
	arguments: [txb.object(COHORT_OBJECT_ID), serializedGithub],
});

(async () => {
	try {
		let txId = await client.signAndExecuteTransactionBlock({ signer: keypair, transactionBlock: txb });
		console.log(`Success! Check our your TX here: https://suiexplorer.com/txblock/${txId.digest}?network=testnet`);
	} catch (e) {
		console.error(`Oops, something went wrong: ${e}`);
	}
})();
