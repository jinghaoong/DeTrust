const { expect } = require("chai");
const { ethers } = require("hardhat");    
const web3 = require("web3");
const bytes32 = require("bytes32");

describe("CommonContract", async () => {

    let ownerAddress, user1Address, user2Address, user3Address, user4Address;
    let baseContractAddress, commonContractAddress, trustScoreAddress, deTrustTokenAddress, votingMechanismAddress;
    let baseContract, commonContract, trustScore, deTrustToken, votingMechanism;
    let owner, user1, user2, user3, user4, a1, a2, a3, a4, a5;

    let creationTime, verificationStart, string1, string2;
    
    before(async () => {

        [owner, user1, user2, user3, user4, a1, a2, a3, a4, a5] = await ethers.getSigners();

        ownerAddress = await owner.getAddress();
        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();
        user3Address = await user3.getAddress();
        user4Address = await user4.getAddress();

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

        await deTrustToken.connect(owner).setApproval(baseContractAddress);
        await deTrustToken.connect(owner).setApproval(votingMechanismAddress);
        await trustScore.connect(owner).approveAddress(baseContractAddress);
        await trustScore.connect(owner).approveAddress(votingMechanismAddress);
        await baseContract.connect(owner).setVotingAccess(votingMechanismAddress);

        await deTrustToken.connect(owner).mintFor(user1Address, 1000);
        await deTrustToken.connect(owner).mintFor(user2Address, 1000);
        await trustScore.connect(owner).setTrustScore(user1Address, 450);
        await trustScore.connect(owner).setTrustScore(user2Address, 450);

        await deTrustToken.connect(user1).approve(baseContractAddress, 20);
        await deTrustToken.connect(user2).approve(baseContractAddress, 20); 

        const commonInput =
            [baseContractAddress, [user1Address, user3Address], 
            [user2Address, user4Address], user2Address, user1Address,
            "common1", "type1", ["ob1", "ob2"], ["desc1", "desc2"], [10000000000, 30000000000], 2, 0];

        const CommonContract = await ethers.getContractFactory("CommonContract");
        commonContract = await CommonContract.connect(user2).deploy(commonInput);
        commonContractAddress = await commonContract.getAddress();

        const finalTokenBalance1 = await deTrustToken.balanceOf(user1Address);
        const finalTokenBalance2 = await deTrustToken.balanceOf(user2Address);
        expect(finalTokenBalance1).to.equal(980);
        expect(finalTokenBalance2).to.equal(980);

        creationTime = Math.floor(Date.now() / 1000) - 9000;
        verificationStart = Math.floor(Date.now() / 1000) - 6000;
        string1 = web3.utils.padLeft(web3.utils.fromAscii("ad1"), 64);
        string2 = web3.utils.padLeft(web3.utils.fromAscii("ad2"), 64);

        const changedProperties = [
            1, 2, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 4, 2, false, verificationStart];

        const changeProperties = await baseContract.connect(owner).setGeneralRepo(1, changedProperties);
        expect(changeProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(1);

    });

    it ("Should be able to resolve obligations", async () => {
        await expect(commonContract.connect(a2).resolveObligation(0, { value: 10000000000 }))
            .to.be.revertedWith("You are not the payer!");

        await expect(commonContract.connect(user2).verifyObligationDone(0))
            .to.be.revertedWith("Obligation is not done yet!");
      
        const initBalance = await ethers.provider.getBalance(commonContractAddress);

        const initContractState = await commonContract.checkContractState();
        expect(initContractState[0]).to.equal(false);
        expect(initContractState[1]).to.equal(false);

        const obligation1 = await commonContract.connect(user1).resolveObligation(0, { value: 10000000000 });
        expect(obligation1).to.emit(commonContract, "ObligationDone").withArgs(0);
        const balance1 = await ethers.provider.getBalance(commonContractAddress);

        const checkObligation1 = await commonContract.checkObligationState(0);
        expect(checkObligation1[0]).to.equal(true);
        expect(checkObligation1[1]).to.equal(false);

        const contractState1 = await commonContract.checkContractState();
        expect(contractState1[0]).to.equal(false);
        expect(contractState1[1]).to.equal(false);
      
        await expect(commonContract.connect(user3).resolveObligation(0, { value: 10000000000 }))
            .to.be.revertedWith("This obligation has been done!");

        await expect(commonContract.connect(user3).resolveObligation(1, { value: 40000000000 }))
            .to.be.revertedWith("You have not paid the correct amount!");

        const obligation2 = await commonContract.connect(user3).resolveObligation(1, { value: 30000000000 });
        expect(obligation2).to.emit(commonContract, "ObligationDone").withArgs(1);
        const balance2 = await ethers.provider.getBalance(commonContractAddress);
        

        const checkObligation2 = await commonContract.checkObligationState(1);
        expect(checkObligation2[0]).to.equal(true);
        expect(checkObligation2[1]).to.equal(false);

        const contractState2 = await commonContract.checkContractState();
        expect(contractState2[0]).to.equal(true);
        expect(contractState2[1]).to.equal(false);

        expect(balance1 - initBalance).to.equal(10000000000);
        expect(balance2 - balance1).to.equal(30000000000);
    });

    it ("Should be able to verify obligations", async () => {
        await expect(commonContract.connect(user1).verifyObligationDone(0))    
            .to.be.revertedWith("You are not the payee!");

        const obligation1 = await commonContract.connect(user4).verifyObligationDone(0);
        expect(obligation1).to.emit(commonContract, "ObligationVerified").withArgs(0);

        const checkObligation1 = await commonContract.checkObligationState(0);
        expect(checkObligation1[0]).to.equal(true);

        const contractState = await commonContract.checkContractState();
        expect(contractState[0]).to.equal(true);
        expect(contractState[1]).to.equal(false);

        const obligation2 = await commonContract.connect(user2).verifyObligationDone(1);
        expect(obligation2).to.emit(commonContract, "ObligationVerified").withArgs(1);

        const checkObligation2 = await commonContract.checkObligationState(1);
        expect(checkObligation2[0]).to.equal(true);

        const finalContractState = await commonContract.checkContractState();
        expect(finalContractState[0]).to.equal(true);
        expect(finalContractState[1]).to.equal(true);
    });

    it ("Should be able to withdraw funds", async () => {
        await expect(commonContract.connect(user2).endContract())
            .to.be.revertedWith("Contract balance is not withdrawn yet!");

        await expect(commonContract.connect(user1).initiatorWithdraw())
            .to.be.revertedWith("You are not the initiator!");

        const initialWealth = await ethers.provider.getBalance(user2Address);

        const withdraw = await commonContract.connect(user2).initiatorWithdraw();
        expect(withdraw).to.emit(commonContract, "InitiatorWithdrawn").withArgs(40000000000);
        const w = await withdraw.wait();
        const gases = BigInt(w.gasUsed) * BigInt(w.gasPrice);

        const finalWealth = await ethers.provider.getBalance(user2Address);
        expect(finalWealth + gases - initialWealth).to.equal(40000000000);

        await expect(commonContract.connect(user2).initiatorWithdraw())
            .to.be.revertedWith("No balance to withdraw!");
    });

    it ("Should be able to complete contract", async () => {
        await expect(commonContract.connect(owner).endContract())
            .to.be.revertedWith("You are not involved in this contract!");
      
        const complete = await commonContract.connect(user1).endContract();
        expect(complete)
        .to.emit(commonContract, "ContractEnded").withArgs(commonContractAddress, 1, user1Address)
        .and.to.emit(baseContract, "ContractPendingComplete").withArgs(1);

        const confirmComplete = await baseContract.connect(user2).completeContract(1);
        expect(confirmComplete).to.emit(baseContract, "ContractCompleted").withArgs(1);

        const finalTrustScore1 = await trustScore.getTrustScore(user1Address);
        const finalTrustScore2 = await trustScore.getTrustScore(user2Address);
        expect(finalTrustScore1).to.equal(451);
        expect(finalTrustScore2).to.equal(451);

        const generalRepo = await baseContract.getGeneralRepo(1);
        expect(generalRepo[0]).to.equal(1);
        expect(generalRepo[1]).to.equal(4);
        expect(generalRepo[10]).to.equal(true);

        await expect(commonContract.connect(user2).initiatorWithdraw())
            .to.be.revertedWith("Contract is inactivated!");
    });

    it ("Working contract should be active", async () => {  
        await deTrustToken.connect(user1).approve(baseContractAddress, 20);
        await deTrustToken.connect(user2).approve(baseContractAddress, 20);

        const newCommonInput =
            [baseContractAddress, [user1Address, user3Address], 
            [user2Address, user4Address], user2Address, user1Address,
            "common1", "type1", ["ob1", "ob2"], ["desc1", "desc2"], [10000000000, 30000000000], 2, 0];

        const CommonContract = await ethers.getContractFactory("CommonContract");
        const newCommonContract = await CommonContract.connect(user2).deploy(newCommonInput);

        const changedProperties1 = [
            2, 0, creationTime, 0, 0, [user1Address, bytes32(0), user2Address, bytes32(0), 0],
            0, 8, 0, 0, false, verificationStart];

        const changeProperties1 = await baseContract.connect(owner).setGeneralRepo(2, changedProperties1);
        expect(changeProperties1).to.emit(baseContract, "PropertiesRecorded").withArgs(2);

        await expect(newCommonContract.connect(user1).resolveObligation(0, { value: 10000000000 }))
            .to.be.revertedWith("Contract is not ready!");

        await expect(newCommonContract.connect(user2).verifyObligationDone(0))
            .to.be.revertedWith("Contract is not ready!");

        const changedProperties2 = [
            2, 5, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 4, 2, false, verificationStart];
      
        const changeProperties2 = await baseContract.connect(owner).setGeneralRepo(2, changedProperties2);
        expect(changeProperties2).to.emit(baseContract, "PropertiesRecorded").withArgs(2);

        await expect(newCommonContract.connect(user1).resolveObligation(0, { value: 10000000000 }))
            .to.be.revertedWith("Contract is not ready!");

        await expect(newCommonContract.connect(user2).verifyObligationDone(0))
            .to.be.revertedWith("Contract is not ready!");

        await expect(newCommonContract.connect(user1).endContract())
            .to.be.revertedWith("Contract is not done yet!");
    });

    it ("Should not create contract with invalid input", async () => {  
        await deTrustToken.connect(user1).approve(baseContractAddress, 20);
        await deTrustToken.connect(user2).approve(baseContractAddress, 20);

        const newCommonInput1 =
            [baseContractAddress, [user1Address, user3Address], 
            [user2Address, user4Address], user2Address, user1Address,
            "common1", "type1", ["ob1", "ob2", "ob3"], ["desc1", "desc2"], [10000000000, 30000000000], 2, 0];

        const newCommonInput2 =
            [baseContractAddress, [user1Address, user3Address], 
            [user2Address, user4Address], user2Address, user1Address,
            "common1", "type1", ["ob1", "ob2"], ["desc1", "desc2", "desc3"], [10000000000, 30000000000], 2, 0];

        const newCommonInput3 =
            [baseContractAddress, [user1Address, user3Address], 
            [user2Address, user4Address], user2Address, user1Address,
            "common1", "type1", ["ob1", "ob2"], ["desc1", "desc2"], [10000000000, 30000000000, 20000000000], 2, 0];

        const CommonContract = await ethers.getContractFactory("CommonContract");
        await expect(CommonContract.connect(user2).deploy(newCommonInput1))
            .to.be.revertedWith("Total obligations does not match obligation titles!");

        await expect(CommonContract.connect(user2).deploy(newCommonInput2))
            .to.be.revertedWith("Total obligations does not match obligation descriptions!");

        await expect(CommonContract.connect(user2).deploy(newCommonInput3))
            .to.be.revertedWith("Total obligations does not match payment amounts!");
    });
});