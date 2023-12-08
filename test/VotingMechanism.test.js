const { expect } = require("chai");
const { ethers } = require("hardhat");   
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const web3 = require("web3");

describe("VotingMechanism", async () => {

    let ownerAddress, user1Address, user2Address, user3Address, user4Address, user5Address, user6Address, user7Address;
    let a1Address, a2Address, a3Address, a4Address, a5Address, a6Address;
    let trustScoreAddress, deTrustTokenAddress, baseContractAddress, votingMechanismAddress, contractAddr;
    let trustScore, deTrustToken, baseContract, votingMechanism;
    let owner, user1, user2, user3, user4, user5, user6, user7, a1, a2, a3, a4, a5, a6;

    let creationTime, verificationStart, string1, string2;
    
    before(async () => {

        [owner, user1, user2, user3, user4, user5, user6, user7, a1, a2, a3, a4, a5, a6] = await ethers.getSigners();

        ownerAddress = await owner.getAddress();
        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();
        user3Address = await user3.getAddress();
        user4Address = await user4.getAddress();
        user5Address = await user5.getAddress();
        user6Address = await user6.getAddress();
        user7Address = await user7.getAddress();

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

        await trustScore.connect(owner).setTrustScore(user1Address, 450);
        await trustScore.connect(owner).setTrustScore(user2Address, 450);
        await trustScore.connect(owner).setTrustScore(user3Address, 450);   
        await trustScore.connect(owner).setTrustScore(user4Address, 450);
        await trustScore.connect(owner).setTrustScore(user5Address, 450);
        await trustScore.connect(owner).setTrustScore(user6Address, 450);
        await trustScore.connect(owner).setTrustScore(user7Address, 450);

        await deTrustToken.connect(owner).mintFor(user1Address, 1020);
        await deTrustToken.connect(owner).mintFor(user2Address, 1020);
        await deTrustToken.connect(owner).mintFor(user3Address, 600);
        await deTrustToken.connect(owner).mintFor(user4Address, 600);
        await deTrustToken.connect(owner).mintFor(user5Address, 600);
        await deTrustToken.connect(owner).mintFor(user6Address, 600);
        await deTrustToken.connect(owner).mintFor(user7Address, 600);
        await deTrustToken.connect(owner).mintFor(baseContractAddress, 500);
        await deTrustToken.connect(owner).setApproval(baseContractAddress);
        await deTrustToken.connect(owner).setApproval(votingMechanismAddress);

        await trustScore.connect(owner).approveAddress(baseContractAddress);
        await trustScore.connect(owner).approveAddress(votingMechanismAddress);

        await baseContract.connect(owner).setVotingAccess(votingMechanismAddress);

        await deTrustToken.connect(user1).approve(baseContractAddress, 20);
        await deTrustToken.connect(user2).approve(baseContractAddress, 20); 

        const commonInput =
            [baseContractAddress, [user1Address, user3Address], 
            [user2Address, user4Address], user2Address, user1Address,
            "common1", "type1", ["ob1", "ob2"], ["desc1", "desc2"], [10000000000, 30000000000], 2, 0];

        const CommonContract = await ethers.getContractFactory("CommonContract");
        const commonContract = await CommonContract.connect(user2).deploy(commonInput);
        contractAddr = await commonContract.getAddress();

        creationTime = Math.floor(Date.now() / 1000) - 9000;
        verificationStart = Math.floor(Date.now() / 1000) - 6000;
        string1 = web3.utils.padLeft(web3.utils.fromAscii("ad1"), 64);
        string2 = web3.utils.padLeft(web3.utils.fromAscii("ad2"), 64);

        const validProperties1 = [
            1, 0, creationTime, 1, 0, [user1Address, string1, user2Address, string2, 2],
            0, 8, 0, 0, false, verificationStart];

        const setProperties = await baseContract.setGeneralRepo(1, validProperties1);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(1);

        a1Address = await a1.getAddress();
        a2Address = await a2.getAddress();
        a3Address = await a3.getAddress();
        a4Address = await a4.getAddress();
        a5Address = await a5.getAddress();
        a6Address = await a6.getAddress();

        await trustScore.connect(owner).setTrustScore(a1Address, 450);
        await trustScore.connect(owner).setTrustScore(a2Address, 450);
        await trustScore.connect(owner).setTrustScore(a3Address, 450);
        await trustScore.connect(owner).setTrustScore(a4Address, 450);
        await trustScore.connect(owner).setTrustScore(a5Address, 450);
        await trustScore.connect(owner).setTrustScore(a6Address, 450);

        await deTrustToken.connect(owner).mintFor(a1Address, 1020); 
        await deTrustToken.connect(owner).mintFor(a2Address, 1020);
        await deTrustToken.connect(owner).mintFor(a3Address, 600);
        await deTrustToken.connect(owner).mintFor(a4Address, 600);
        await deTrustToken.connect(owner).mintFor(a5Address, 600);
        await deTrustToken.connect(owner).mintFor(a6Address, 600);

        await deTrustToken.connect(a1).approve(baseContractAddress, 20);
        await deTrustToken.connect(a2).approve(baseContractAddress, 20);

        const commonInput2 =
            [baseContractAddress, [a1Address], 
            [a2Address], a2Address, a1Address,
            "common1", "type1", ["ob1"], ["desc1"], [10000000000], 1, 0];

        await CommonContract.connect(a2).deploy(commonInput2);

    });

    it ("Should be able to vote a contract", async () => {
        const initTokenBalance3 = await deTrustToken.balanceOf(user3Address);
        const initTokenBalance4 = await deTrustToken.balanceOf(user4Address);
        const initTokenBalance5 = await deTrustToken.balanceOf(user5Address);
        const initTokenBalance6 = await deTrustToken.balanceOf(user6Address);
        const initTokenBalance7 = await deTrustToken.balanceOf(user7Address);
        const initTokenBalanceBase = await deTrustToken.balanceOf(baseContractAddress);
        expect(initTokenBalance3).to.equal(600);
        expect(initTokenBalance4).to.equal(600);
        expect(initTokenBalance5).to.equal(600);
        expect(initTokenBalance6).to.equal(600);
        expect(initTokenBalance7).to.equal(600);
        expect(initTokenBalanceBase).to.equal(580);

        const vote1 = await votingMechanism.connect(user3).verifyContract(1, 1, user3Address);
        expect(vote1).to.emit(votingMechanism, "VerifiedContract").withArgs(1, user3Address, 1);
        const vote2 = await votingMechanism.connect(user4).verifyContract(1, 1, user4Address);
        expect(vote2).to.emit(votingMechanism, "VerifiedContract").withArgs(1, user4Address, 1);
        const vote3 = await votingMechanism.connect(user5).verifyContract(1, 2, user5Address);
        expect(vote3).to.emit(votingMechanism, "VerifiedContract").withArgs(1, user5Address, 2);
        const vote4 = await votingMechanism.connect(user6).verifyContract(1, 1, user6Address);
        expect(vote4).to.emit(votingMechanism, "VerifiedContract").withArgs(1, user6Address, 1);
        const vote5 = await votingMechanism.connect(user7).verifyContract(1, 1, user7Address);
        expect(vote5).to.emit(votingMechanism, "VerifiedContract").withArgs(1, user7Address, 1)

        const generalRepo = await baseContract.getGeneralRepo(1);
        expect(generalRepo[6]).to.equal(0);
        expect(generalRepo[8]).to.equal(4);
        expect(generalRepo[9]).to.equal(1);

        const finalTokenBalance3 = await deTrustToken.balanceOf(user3Address);
        const finalTokenBalance4 = await deTrustToken.balanceOf(user4Address);
        const finalTokenBalance5 = await deTrustToken.balanceOf(user5Address);
        const finalTokenBalance6 = await deTrustToken.balanceOf(user6Address);
        const finalTokenBalance7 = await deTrustToken.balanceOf(user7Address);
        const finalTokenBalanceBase = await deTrustToken.balanceOf(baseContractAddress);
        expect(finalTokenBalance3).to.equal(610);
        expect(finalTokenBalance4).to.equal(610);
        expect(finalTokenBalance5).to.equal(610);
        expect(finalTokenBalance6).to.equal(610);
        expect(finalTokenBalance7).to.equal(610);
        expect(finalTokenBalanceBase).to.equal(530);

    });

    it ("Should be able to resolve verification result", async () => {
        const initTokenBalance5 = await deTrustToken.balanceOf(user5Address);
        expect(initTokenBalance5).to.equal(610);

        const initTrustScore1 = await trustScore.getTrustScore(user1Address);
        const initTrustScore2 = await trustScore.getTrustScore(user2Address);
        const initTrustScore5 = await trustScore.getTrustScore(user5Address);
        expect(initTrustScore1).to.equal(450);
        expect(initTrustScore2).to.equal(450);
        expect(initTrustScore5).to.equal(450);

        await expect(votingMechanism.resolveVerification(1))
            .to.be.revertedWith("Resolve is not available yet!");

        const blockNum = await ethers.provider.getBlockNumber();
        const now = await ethers.provider.getBlock(blockNum);
        await time.setNextBlockTimestamp(now.timestamp + 24 * 3600);

        const resolve = await votingMechanism.resolveVerification(1);
        expect(resolve).to.emit(votingMechanism, "PassedVerification").withArgs(1)
        expect(resolve).to.emit(votingMechanism, "VerificationResolved").withArgs(1, 1);

        const generalRepo = await baseContract.getGeneralRepo(1);
        expect(generalRepo[1]).to.equal(2);
        expect(generalRepo[6]).to.equal(1);

        const finalTokenBalance5 = await deTrustToken.balanceOf(user5Address);
        expect(finalTokenBalance5).to.equal(510);

        const finalTrustScore1 = await trustScore.getTrustScore(user1Address);
        const finalTrustScore2 = await trustScore.getTrustScore(user2Address);
        const finalTrustScore5 = await trustScore.getTrustScore(user5Address);
        expect(finalTrustScore1).to.equal(450);
        expect(finalTrustScore2).to.equal(450);
        expect(finalTrustScore5).to.equal(449);
    });

    it ("should be able to vote down a contract", async () => {
        const validProperties2 = [
            1, 0, creationTime + 24 * 3600, 1, 0, [a1Address, string1, a2Address, string2, 2],
            0, 8, 0, 0, false, verificationStart + 24 * 3600];

        const setProperties2 = await baseContract.setGeneralRepo(2, validProperties2);
        expect(setProperties2).to.emit(baseContract, "PropertiesRecorded").withArgs(2);
        const initTokenBalanceBase = await deTrustToken.balanceOf(baseContractAddress);
        expect(initTokenBalanceBase).to.equal(530);

        const vote1 = await votingMechanism.connect(a3).verifyContract(2, 2, a3Address);
        expect(vote1).to.emit(votingMechanism, "VerifiedContract").withArgs(2, a3Address, 2);
        const vote2 = await votingMechanism.connect(a4).verifyContract(2, 2, a4Address);
        expect(vote2).to.emit(votingMechanism, "VerifiedContract").withArgs(2, a4Address, 2);
        const vote3 = await votingMechanism.connect(a5).verifyContract(2, 2, a5Address);
        expect(vote3).to.emit(votingMechanism, "VerifiedContract").withArgs(2, a5Address, 2);
        const vote4 = await votingMechanism.connect(a6).verifyContract(2, 2, a6Address);
        expect(vote4).to.emit(votingMechanism, "VerifiedContract").withArgs(2, a6Address, 2)

        const generalRepo = await baseContract.getGeneralRepo(2);
        expect(generalRepo[6]).to.equal(0);
        expect(generalRepo[8]).to.equal(0);
        expect(generalRepo[9]).to.equal(4);

        const finalTokenBalanceBase = await deTrustToken.balanceOf(baseContractAddress);
        expect(finalTokenBalanceBase).to.equal(490);
    });

    it ("Should be able to resolve fraudulent verification result", async () => {
        const initTokenBalanceA1 = await deTrustToken.balanceOf(a1Address);
        expect(initTokenBalanceA1).to.equal(1000);
        const initTokenBalanceA2 = await deTrustToken.balanceOf(a2Address);
        expect(initTokenBalanceA2).to.equal(1000);

        const initTrustScore1 = await trustScore.getTrustScore(a1Address);
        const initTrustScore2 = await trustScore.getTrustScore(a2Address);
        expect(initTrustScore1).to.equal(450);
        expect(initTrustScore2).to.equal(450);

        const blockNum = await ethers.provider.getBlockNumber();
        const now = await ethers.provider.getBlock(blockNum);
        await time.setNextBlockTimestamp(now.timestamp + 48 * 3600);

        const resolve = await votingMechanism.resolveVerification(2);
        expect(resolve).to.emit(votingMechanism, "FailedVerification").withArgs(2)
        expect(resolve).to.emit(votingMechanism, "VerificationResolved").withArgs(2, 2);

        const generalRepo = await baseContract.getGeneralRepo(2);
        expect(generalRepo[1]).to.equal(5);
        expect(generalRepo[6]).to.equal(2);

        const finalTokenBalanceA1 = await deTrustToken.balanceOf(a1Address);
        expect(finalTokenBalanceA1).to.equal(500);
        const finalTokenBalanceA2 = await deTrustToken.balanceOf(a2Address);
        expect(finalTokenBalanceA2).to.equal(500);

        const finalTrustScore1 = await trustScore.getTrustScore(a1Address);
        const finalTrustScore2 = await trustScore.getTrustScore(a2Address);
        expect(finalTrustScore1).to.equal(448);
        expect(finalTrustScore2).to.equal(448);

    });

    it ("Setter check", async () => {
        await expect(votingMechanism.connect(owner).setTimeRange(7 * 24 * 3600, 5 * 24 * 3600))
            .to.be.revertedWith("Invalid time range!");

        const setTimeRange = await votingMechanism.connect(owner).setTimeRange(5 * 24 * 3600, 9 * 24 * 3600);
        expect(setTimeRange).to.emit(votingMechanism, "UpdateTimeRange").withArgs(5 * 24 * 3600, 9 * 24 * 3600);

        await expect(votingMechanism.connect(user1).setMinimumTimeFrame(7 * 24 * 3600))
            .to.be.revertedWith("You are not the owner!");
        
        const setMinimumTimeFrame = await votingMechanism.connect(owner).setMinimumTimeFrame(7 * 24 * 3600);
        expect(setMinimumTimeFrame).to.emit(votingMechanism, "UpdateMinTimeFrame").withArgs(7 * 24 * 3600);

        await expect(votingMechanism.connect(user1).setVerificationCutOffTime(7 * 24 * 3600))
            .to.be.revertedWith("You are not the owner!");
        
        const setVerificationCutOffTime = await votingMechanism.connect(owner).setVerificationCutOffTime(30 * 24 * 3600);
        expect(setVerificationCutOffTime).to.emit(votingMechanism, "UpdateVerificationMaxTime").withArgs(30 * 24 * 3600);
    });
});