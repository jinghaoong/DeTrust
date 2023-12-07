const bytes32 = require("bytes32");
const { expect } = require("chai");
const { ethers } = require("hardhat");    
const web3 = require("web3");

describe("BaseContract", async () => {

    let ownerAddress, user1Address, user2Address;
    let baseContractAddress, signingMechanismAddress, trustScoreAddress, deTrustTokenAddress;
    let baseContract, signingMechanism, trustScore, deTrustToken;
    let owner, user1, user2, a1, a2, a3, a4, a5;

    let contractInput;
    
    before(async () => {

        [owner, user1, user2, a1, a2, a3, a4, a5] = await ethers.getSigners();

        ownerAddress = await owner.getAddress();
        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();

        console.log("Initiated hardhat network accounts!");

        trustScore = await ethers.deployContract("TrustScore", [200]);
        trustScoreAddress = await trustScore.getAddress();
        console.log("Deployed TrustScore contract: ", trustScoreAddress);

        deTrustToken = await ethers.deployContract("DeTrustToken", [1000000000000000]);
        deTrustTokenAddress = await deTrustToken.getAddress();
        console.log("Deployed DeTrustToken contract: ", deTrustTokenAddress);

        baseContract = await ethers.deployContract("BaseContract", 
            [trustScoreAddress, deTrustTokenAddress]);
        baseContractAddress = await baseContract.getAddress();
        console.log("Deployed BaseContract contract: ", baseContractAddress);

        console.log("Completed deployment of backbone contracts!");

        signingMechanism = await ethers.deployContract("SigningMechanism",
            [baseContractAddress]);
        signingMechanismAddress = await signingMechanism.getAddress();
        console.log("Deployed SigningMechanism contract: ", signingMechanismAddress);

        await deTrustToken.connect(owner).setApproval(baseContractAddress);
        await trustScore.connect(owner).approveAddress(baseContractAddress);
        await baseContract.connect(owner).setApproval(signingMechanismAddress);

        console.log("Completed init account settings!");

    });

    it ("Should be able to generate message hash", async () => {
        const messageHash = await signingMechanism.connect(user1).getMessageHash(
            user1Address, 1, 12345, 2, web3.utils.fromAscii('0xff'), web3.utils.fromAscii('0x11'));
        expect(messageHash).to.not.equal(undefined);
        expect(messageHash).to.not.equal(null);

        const messageHash2 = await signingMechanism.connect(user1).getMessageHash(
            user1Address, 1, 12345, 2, web3.utils.fromAscii('0xff'), web3.utils.fromAscii('0x11'));
        expect(messageHash).equal(messageHash2);
        console.log("\n\nSuccessfully generate message hash: ", messageHash);

    });

    it ("Should be able to sign contract", async () => {
        const creationTime = Date.now() - 36000;
        const initSignature = bytes32(0);
        const validProperties1 = [
            1, 
            0, 
            creationTime, 
            0, 
            0, 
            [user1Address, initSignature, user2Address, initSignature, 0],
            0,
            8,
            0,
            0,
            false];

        const setProperties = await baseContract.setGeneralRepo(1, validProperties1);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(1);
        console.log("\n\nSuccessfully set properties for default contract id 1");

        const hash1 = await signingMechanism.connect(user1).getMessageHash(
            user1Address, 1, 12345, 2, web3.utils.fromAscii('0xff'), web3.utils.fromAscii('0x11'));
        const hash2 = await signingMechanism.connect(user2).getMessageHash(
            user2Address, 1, 54321, 5, web3.utils.fromAscii('0xaa'), web3.utils.fromAscii('0x22'));

        const sign1 = await signingMechanism.connect(user1)
            .sign(1, 12345, 2, web3.utils.fromAscii('0xff'), web3.utils.fromAscii('0x11'));
        expect(sign1).to.emit(signingMechanism, "ContractSigned").withArgs(1, user1Address);
        const generalRepo1 = await baseContract.getGeneralRepo(1);
        expect(generalRepo1[1]).to.equal(0);
        expect(generalRepo1[5][1]).to.equal(hash1);
        expect(generalRepo1[5][4]).to.equal(1);
        console.log("Successfully signed contract 1!");

        const sign2 = await signingMechanism.connect(user2)
            .sign(1, 54321, 5, web3.utils.fromAscii('0xaa'), web3.utils.fromAscii('0x22'));
        expect(sign2).to.emit(signingMechanism, "ContractSigned").withArgs(1, user2Address);
        const generalRepo2 = await baseContract.getGeneralRepo(1);
        expect(generalRepo2[1]).to.equal(1);
        expect(generalRepo2[5][3]).to.equal(hash2);
        expect(generalRepo2[5][4]).to.equal(2);
        console.log("Successfully signed contract 2!");
    });

    it ("Should be able to verify signature", async () => { 
        const creationTime = Date.now() - 36000;

        const hash1 = await signingMechanism.connect(user1).getMessageHash(
            user1Address, 2, 12345, 2, web3.utils.fromAscii('0xff'), web3.utils.fromAscii('0x11'));
        const hash2 = await signingMechanism.connect(user2).getMessageHash(
            user2Address, 2, 54321, 5, web3.utils.fromAscii('0xaa'), web3.utils.fromAscii('0x22'));

        const validProperties2 = [
            2, 
            2, 
            creationTime, 
            0, 
            0, 
            [user1Address, hash1, user2Address, hash2, 2],
            1,
            8,
            4,
            0,
            false];
        const setProperties = await baseContract.setGeneralRepo(2, validProperties2);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(2);
        console.log("\n\nSuccessfully set properties for default contract id 2");

        const verify1 = await signingMechanism.verifySignature(user1Address, 2, 12345, 2, 
            web3.utils.fromAscii('0xff'), web3.utils.fromAscii('0x11'));
        expect(verify1).to.be.true;
        console.log("Successfully verified signature 1!");

        const verify2 = await signingMechanism.verifySignature(user2Address, 2, 54321, 5, 
            web3.utils.fromAscii('0xaa'), web3.utils.fromAscii('0x22'));
        expect(verify2).to.be.true;
        console.log("Successfully verified signature 2!");

        console.log("Successfully verified all signatures!");
    });
});