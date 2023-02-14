import { deployAndVerify } from './contract.mjs';
import { writeFile } from 'fs/promises';
import dotenv from 'dotenv';
import esMain from 'es-main';

dotenv.config({
  path: `.env.${process.env.CHAIN}`
});

export async function setupContracts() {
  const zoraERC721TransferHelperAddress = process.env.ZORA_ERC_721_TRANSFER_HELPER_ADDRESS;

  if (!zoraERC721TransferHelperAddress) {
    throw new Error('erc721 transfer helper address is required');
  }

  console.log('deploying Erc721Drop');
  const dropContract = await deployAndVerify('src/ERC721Drop.sol:ERC721Drop', [
    zoraERC721TransferHelperAddress
  ]);
  const dropContractAddress = dropContract.deployed.deploy.deployedTo;
  console.log('deployed drop contract to ', dropContractAddress);
  console.log('deploying drops metadata');
  const dropMetadataContract = await deployAndVerify(
    'src/metadata/DropMetadataRenderer.sol:DropMetadataRenderer',
    []
  );
  const dropMetadataAddress = dropMetadataContract.deployed.deploy.deployedTo;
  console.log('deployed drops metadata to', dropMetadataAddress);

  console.log('deploying creator implementation');
  const creatorImpl = await deployAndVerify('src/ZoraNFTCreatorV1.sol:ZoraNFTCreatorV1', [
    dropContractAddress,
    dropMetadataAddress
  ]);
  console.log('deployed creator implementation to', creatorImpl.deployed.deploy.deployedTo);

  return {
    dropContract,
    dropMetadataContract,
    creatorImpl
  };
}

async function main() {
  const output = await setupContracts();
  const date = new Date().toISOString().slice(0, 10);
  writeFile(`./deployments/${date}.${process.env.CHAIN}.json`, JSON.stringify(output, null, 2));
}

if (esMain(import.meta)) {
  // Run main
  await main();
}
