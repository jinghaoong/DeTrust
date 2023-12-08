import { ethers } from "hardhat";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", await deployer.getAddress());  

  const accounts = await ethers.deployContract("Accounts");

  const deTrustParams = [1000000000];
  const deTrustToken = await ethers.deployContract("DeTrustToken", deTrustParams);

  const trustScoreParams = [200];
  const trustScore = await ethers.deployContract("TrustScore", trustScoreParams);

  await accounts.waitForDeployment();
  await deTrustToken.waitForDeployment();
  await trustScore.waitForDeployment();

  const trustScoreAddress = await trustScore.getAddress();
  const deTrustTokenAddress = await deTrustToken.getAddress();

  console.log("Accounts deployed to:", await accounts.getAddress());
  console.log("TrustScore deployed to:", trustScoreAddress);
  console.log("DeTrustToken deployed to:", deTrustTokenAddress);

  const contractUtility = await ethers.getContractFactory("ContractUtility");
  const contractUtilityInstance = await contractUtility.deploy();
  await contractUtilityInstance.waitForDeployment();

  console.log("ContractUtility deployed to:", await contractUtilityInstance.getAddress());

  const baseContractParams = [trustScoreAddress, deTrustTokenAddress];
  const baseContract = await ethers.deployContract("BaseContract", baseContractParams);
  await baseContract.waitForDeployment();

  const baseContractAddress = await baseContract.getAddress();

  console.log("BaseContract deployed to:", baseContractAddress);

  const votingMechanismParams = [baseContractAddress, deTrustTokenAddress, trustScoreAddress];  
  const baseAsParams = [baseContractAddress];

  const votingMechanism = await ethers.deployContract("VotingMechanism", votingMechanismParams);
  const signingMechanism = await ethers.deployContract("SigningMechanism", baseAsParams);
  const communicationChannel = await ethers.deployContract("CommunicationChannel", baseAsParams);

  await votingMechanism.waitForDeployment();
  await signingMechanism.waitForDeployment();
  await communicationChannel.waitForDeployment();

  const votingMechanismAddress = await votingMechanism.getAddress();
  const signingMechanismAddress = await signingMechanism.getAddress();
  const communicationChannelAddress = await communicationChannel.getAddress();

  console.log("VotingMechanism deployed to:", votingMechanismAddress);
  console.log("SigningMechanism deployed to:", signingMechanismAddress);
  console.log("CommunicationChannel deployed to:", communicationChannelAddress);

  await deTrustToken.setApproval(baseContractAddress);
  await deTrustToken.setApproval(votingMechanismAddress);  
  await trustScore.approveAddress(baseContractAddress);
  await trustScore.approveAddress(votingMechanismAddress);
  await baseContract.setApproval(votingMechanismAddress);  
  await baseContract.setVotingAccess(votingMechanismAddress);  
  await baseContract.setApproval(signingMechanismAddress);  
  await baseContract.setApproval(communicationChannelAddress);

  console.log("Approvals set");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
