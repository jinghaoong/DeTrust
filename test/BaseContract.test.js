const { expect } = require("chai");
const { ethers } = require("hardhat");    
const web3 = require("web3");
const bytes32 = require("bytes32");

describe("BaseContract", async () => {

    let ownerAddress, user1Address, user2Address, user3Address, user4Address, user5Address, user6Address;
    let trustScoreAddress, deTrustTokenAddress, baseContractAddress, votingMechanismAddress, contractAddr, commonContractAddress;
    let trustScore, deTrustToken, baseContract, votingMechanism;
    let owner, user1, user2, user3, user4, user5, user6, a1, a2, a3, a4, a5;

    let contractInput, creationTime, verificationStart, string1, string2;
    
    before(async () => {

        [owner, user1, user2, user3, user4, user5, user6, a1, a2, a3, a4, a5] = await ethers.getSigners();

        ownerAddress = await owner.getAddress();
        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();
        user3Address = await user3.getAddress();
        user4Address = await user4.getAddress();
        user5Address = await user5.getAddress();
        user6Address = await user6.getAddress();
      
        trustScore = await ethers.deployContract("TrustScore", [200]);
        trustScoreAddress = await trustScore.getAddress();

        deTrustToken = await ethers.deployContract("DeTrustToken", [1000000000000000]);
        deTrustTokenAddress = await deTrustToken.getAddress();

        baseContract = await ethers.deployContract("BaseContract", 
            [trustScoreAddress, deTrustTokenAddress]);
        baseContractAddress = await baseContract.getAddress();

        votingMechanism = await ethers.deployContract("VotingMechanism",
            [baseContractAddress, deTrustTokenAddress, trustScoreAddress]);
        votingMechanismAddress = await votingMechanism.getAddress();

        contractAddr = await a1.getAddress();
        contractInput = [contractAddr, 0, 0, user1Address, user2Address, user1Address, user2Address];

        await trustScore.connect(owner).setTrustScore(user1Address, 450);
        await trustScore.connect(owner).setTrustScore(user2Address, 450);

        await deTrustToken.connect(owner).mintFor(user1Address, 1000);
        await deTrustToken.connect(owner).mintFor(user2Address, 1000);
        await deTrustToken.connect(owner).setApproval(baseContractAddress);
        await deTrustToken.connect(owner).setApproval(votingMechanismAddress);

        await deTrustToken.connect(user1).approve(baseContractAddress, 20);   
        await deTrustToken.connect(user2).approve(baseContractAddress, 20);
        await trustScore.connect(owner).approveAddress(baseContractAddress);
        await trustScore.connect(owner).approveAddress(votingMechanismAddress);

        await baseContract.connect(owner).setVotingAccess(votingMechanismAddress);

        creationTime = Math.floor(Date.now() / 1000) - 9000;
        verificationStart = Math.floor(Date.now() / 1000) - 6000;
        string1 = web3.utils.padLeft(web3.utils.fromAscii("ad1"), 64);
        string2 = web3.utils.padLeft(web3.utils.fromAscii("ad2"), 64);

        const validProperties1 = [
            6, 0, creationTime, 0, 0, [user1Address, string1, user2Address, bytes32(0), 1],
            0, 8, 0, 0, false, verificationStart];

        const validProperties2 = [
            7, 2, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 4, 0, false, verificationStart];

        const setProperties = await baseContract.setGeneralRepo(6, validProperties1);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(6);

        const setProperties2 = await baseContract.setGeneralRepo(7, validProperties2);
        expect(setProperties2).to.emit(baseContract, "PropertiesRecorded").withArgs(7);
    });

    it("Should be able to record a new contract", async () => {
        const initTokenBalance1 = await deTrustToken.balanceOf(user1Address);
        const initTokenBalance2 = await deTrustToken.balanceOf(user2Address);
        const initTokenBalance3 = await deTrustToken.balanceOf(baseContractAddress);
        expect(initTokenBalance1).to.equal(1000);
        expect(initTokenBalance2).to.equal(1000);
        expect(initTokenBalance3).to.equal(0);

        const logContract = await baseContract.addToContractRepo(contractInput);
        expect(logContract).to.emit(baseContract, "ContractLogged").withArgs(contractAddr, 1);

        const finalTokenBalance1 = await deTrustToken.balanceOf(user1Address);
        const finalTokenBalance2 = await deTrustToken.balanceOf(user2Address);
        const finalTokenBalance3 = await deTrustToken.balanceOf(baseContractAddress);
        expect(finalTokenBalance1).to.equal(980);
        expect(finalTokenBalance2).to.equal(980);
        expect(finalTokenBalance3).to.equal(40);
        
        const generalRepo = await baseContract.getGeneralRepo(1);
        expect(generalRepo[0]).to.equal(1); // counter
        expect(generalRepo[1]).to.equal(0); // draft
        expect(generalRepo[3]).to.equal(0); // common type
        expect(generalRepo[4]).to.equal(0); // dispute type
        expect(generalRepo[6]).to.equal(0); // pending verification
        expect(generalRepo[7]).to.equal(8); // verifier amount
        expect(generalRepo[8]).to.equal(0); 
        expect(generalRepo[9]).to.equal(0);
        expect(generalRepo[10]).to.equal(false);
        
        const addressMapping = await baseContract.getAddressRepo(1);
        expect(addressMapping).to.equal(contractAddr);

        const idMapping = await baseContract.getIdRepo(contractAddr);
        expect(idMapping).to.equal(1);

        const walletAddress1 = await baseContract.getWalletAddress(user1Address);
        expect(walletAddress1).to.equal(user1Address);

        const walletAddress2 = await baseContract.getWalletAddress(user2Address);
        expect(walletAddress2).to.equal(user2Address);

        const active = await baseContract.isActive(1);
        expect(active).to.equal(true);

        const involvedOwner = await baseContract.isInvolved(1, owner);
        expect(involvedOwner).to.equal(false);

        const involvedUser1 = await baseContract.isInvolved(1, user1);
        expect(involvedUser1).to.equal(true);

        const involvedUser2 = await baseContract.isInvolved(1, user2);
        expect(involvedUser2).to.equal(true);
    });

    it("Should be able to proceed verified contract", async () => {
        const validProperties = [
            2, 1, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 5, 1, false, verificationStart];

        const setProperties = await baseContract.setGeneralRepo(2, validProperties);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(2);

        const checkGeneralRepo = await baseContract.getGeneralRepo(2);
        expect(checkGeneralRepo[0]).to.equal(2); // counter
        expect(checkGeneralRepo[1]).to.equal(1); 
        expect(checkGeneralRepo[2]).to.equal(creationTime);
        expect(checkGeneralRepo[3]).to.equal(0); 
        expect(checkGeneralRepo[4]).to.equal(0);
        expect(checkGeneralRepo[5][0]).to.equal(user1Address);
        expect(checkGeneralRepo[5][1]).to.equal(string1);
        expect(checkGeneralRepo[5][2]).to.equal(user2Address);
        expect(checkGeneralRepo[5][3]).to.equal(string2);
        expect(checkGeneralRepo[5][4]).to.equal(2);
        expect(checkGeneralRepo[6]).to.equal(1);
        expect(checkGeneralRepo[7]).to.equal(8);
        expect(checkGeneralRepo[8]).to.equal(5);
        expect(checkGeneralRepo[9]).to.equal(1);
        expect(checkGeneralRepo[10]).to.equal(false);
        expect(checkGeneralRepo[11]).to.equal(verificationStart);

        await expect(baseContract.connect(user3).proceedContract(2))
            .to.be.revertedWith("You are not authorized to execute this function!");

        const proceedContract = await baseContract.connect(user1).proceedContract(2);
        expect(proceedContract).to.emit(baseContract, "ContractProceeded").withArgs(2);

        const generalRepo = await baseContract.getGeneralRepo(2);
        expect(generalRepo[0]).to.equal(2); // counter
        expect(generalRepo[1]).to.equal(2); // In progress
    });

    it("Should be able to complete contract", async () => {
        const validProperties = [
            3, 2, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 4, 0, false, verificationStart];

        const setProperties = await baseContract.setGeneralRepo(3, validProperties);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(3);

        const initTrustScore1 = await trustScore.getTrustScore(user1Address);
        const initTrustScore2 = await trustScore.getTrustScore(user2Address);
        expect(initTrustScore1).to.equal(450);
        expect(initTrustScore2).to.equal(450);

        await expect(baseContract.connect(user3).completeContract(2))
            .to.be.revertedWith("You are not authorized to execute this function!");

        const completeContract = await baseContract.connect(user1).completeContract(3);
        expect(completeContract).to.emit(baseContract, "ContractPendingComplete").withArgs(3);

        const generalRepo = await baseContract.getGeneralRepo(3);
        expect(generalRepo[10]).to.equal(true); 

        const completeContract2 = await baseContract.connect(user2).completeContract(3);
        expect(completeContract2).to.emit(baseContract, "ContractCompleted").withArgs(3);

        const generalRepo2 = await baseContract.getGeneralRepo(3);
        expect(generalRepo2[1]).to.equal(4);
        expect(generalRepo2[10]).to.equal(true);
      
        const active = await baseContract.isActive(3);
        expect(active).to.equal(false);

        const finalTrustScore1 = await trustScore.getTrustScore(user1Address);
        const finalTrustScore2 = await trustScore.getTrustScore(user2Address);
        expect(finalTrustScore1).to.equal(451);
        expect(finalTrustScore2).to.equal(451);
    });

    it ("Should be able to void contract", async () => {
        const validProperties = [
            4, 2, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 4, 0, false, verificationStart];

        const setProperties = await baseContract.setGeneralRepo(4, validProperties);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(4);

        await expect(baseContract.connect(user3).voidContract(4))
            .to.be.revertedWith("You are not authorized to execute this function!");

        const voidContract = await baseContract.connect(user1).voidContract(4);
        expect(voidContract).to.emit(baseContract, "ContractVoided").withArgs(4);

        const generalRepo = await baseContract.getGeneralRepo(4);
        expect(generalRepo[1]).to.equal(5);

        const active = await baseContract.isActive(4);
        expect(active).to.equal(false);
    });

    it ("Should be able to record dispute on contract", async () => {
        const validProperties = [
            5, 2, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 4, 0, false, verificationStart];

        const setProperties = await baseContract.setGeneralRepo(5, validProperties);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(5);

        const disputeContractAddress = await a2.getAddress();

        await expect(baseContract.connect(owner).disputeContract(5, disputeContractAddress, 1))
            .to.be.revertedWith("You are not involved in this contract!");

        const disputeContract = await baseContract.connect(user1)
            .disputeContract(5, disputeContractAddress, 1);
        expect(disputeContract).to.emit(baseContract, "ContractDisputeRecorded").withArgs(5);

        const generalRepo = await baseContract.getGeneralRepo(5);
        expect(generalRepo[1]).to.equal(3);
        expect(generalRepo[4]).to.equal(1);

        const disputeRepo = await baseContract.getDisputeContract(5);
        expect(disputeRepo).to.equal(disputeContractAddress);
    });

    it ("Should be able to check if contract is inprogress", async () => {
        const checkInProgress = await baseContract.isContractReady(6);
        expect(checkInProgress).to.equal(false);

        const checkInProgress2 = await baseContract.isContractReady(7);
        expect(checkInProgress2).to.equal(true);
    });

    it ("Should be able to check if contract is signed", async () => {
        await expect(baseContract.connect(user1)
            .isSigned(6)).to.be.revertedWith("Contract is not signed by both parties!");

        const checkSigned2 = await baseContract.isSigned(7);
        expect(checkSigned2).to.equal(true);
    });

    it ("Setter check", async () => {
        const basicProperties = [
            8, 0, creationTime, 0, 0, [user1Address, bytes32(0), user2Address, bytes32(0), 0],
            0, 8, 0, 0, false, verificationStart];

        await expect(baseContract.connect(user1).setGeneralRepo(8, basicProperties))
            .to.be.revertedWith("You are not approved to execute this function!");

        const setProperties = await baseContract.connect(owner).setGeneralRepo(8, basicProperties);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(8);

        await expect(baseContract.connect(user1).setWalletMapping(user1Address, user2Address))
            .to.be.revertedWith("You are not approved to execute this function!");

        const setWalletMapping = await baseContract.connect(owner).setWalletMapping(user1Address, user2Address);
        expect(setWalletMapping).to.emit(baseContract, "WalletSet").withArgs(user1Address);

        await expect(baseContract.connect(user1).setApproval(baseContractAddress))
            .to.be.revertedWith("You are not the owner!");
        
        const setApproval = await baseContract.connect(owner).setApproval(baseContractAddress);
        expect(setApproval).to.emit(baseContract, "SetApprovalToBase").withArgs(baseContractAddress);

        await expect(baseContract.connect(user1).setVotingAccess(votingMechanismAddress))
            .to.be.revertedWith("You are not the owner!");
        
        const setVotingAccess = await baseContract.connect(owner).setVotingAccess(votingMechanismAddress);
        expect(setVotingAccess).to.emit(baseContract, "SetVotingMechanism").withArgs(votingMechanismAddress);

    });

    it ("Getter check", async () => {
        await expect(baseContract.connect(user3).getGeneralRepo(8))
            .to.be.revertedWith("You are not authorized to execute this function!");

        const getGeneralRepo = await baseContract.getGeneralRepo(1);
        expect(getGeneralRepo[0]).to.equal(1);

        await expect(baseContract.connect(user1).getWalletAddress(user2Address))
            .to.be.revertedWith("You are not approved to execute this function!");

        const getWalletAddress = await baseContract.connect(owner).getWalletAddress(user2Address);
        expect(getWalletAddress).to.equal(user2Address);

        await expect(baseContract.connect(user3).getDisputeContract(5))
            .to.be.revertedWith("You are not authorized to execute this function!");

        const getDisputeContract = await baseContract.connect(user1).getDisputeContract(5);
        expect(getDisputeContract).to.equal(await a2.getAddress());

        const getAddress = await baseContract.connect(user3).getAddressRepo(1);
        expect(getAddress).to.equal(contractAddr);

        const getId = await baseContract.connect(user4).getIdRepo(contractAddr);
        expect(getId).to.equal(1);
    });
});