const { expect } = require("chai");
const { ethers } = require("hardhat");    
const web3 = require("web3");

describe("CommunicationChannel", async () => {

    let ownerAddress, user1Address, user2Address;
    let baseContractAddress, communicationChannelAddress, trustScoreAddress, deTrustTokenAddress;
    let baseContract, communicationChannel, trustScore, deTrustToken;
    let owner, user1, user2, a1, a2, a3, a4, a5;
    let creationTime, verificationStart, string1, string2;

    before(async () => {

        [owner, user1, user2, a1, a2, a3, a4, a5] = await ethers.getSigners();

        ownerAddress = await owner.getAddress();
        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();

        trustScore = await ethers.deployContract("TrustScore", [200]);
        trustScoreAddress = await trustScore.getAddress();

        deTrustToken = await ethers.deployContract("DeTrustToken", [1000000000000000]);
        deTrustTokenAddress = await deTrustToken.getAddress();

        baseContract = await ethers.deployContract("BaseContract", 
            [trustScoreAddress, deTrustTokenAddress]);
        baseContractAddress = await baseContract.getAddress();

        communicationChannel = await ethers.deployContract("CommunicationChannel",
            [baseContractAddress]);
        communicationChannelAddress = await communicationChannel.getAddress();

        await deTrustToken.connect(owner).setApproval(baseContractAddress);
        await trustScore.connect(owner).approveAddress(baseContractAddress);
        await baseContract.connect(owner).setApproval(communicationChannelAddress);
      
        creationTime = Math.floor(Date.now() / 1000) - 9000;
        verificationStart = Math.floor(Date.now() / 1000) - 6000;
        string1 = web3.utils.padLeft(web3.utils.fromAscii("ad1"), 64);
        string2 = web3.utils.padLeft(web3.utils.fromAscii("ad2"), 64);
    });

    it("Should be able to send message", async () => {
        const validProperties1 = [
            1, 2, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 4, 0, false, verificationStart];

        const setProperties = await baseContract.setGeneralRepo(1, validProperties1);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(1);
        
        const sendMessage = await communicationChannel.connect(user1).sendMessage(1, "Hello");
        expect(sendMessage)
            .to.emit(communicationChannel, "MessageSent").withArgs(1, user1Address, "Hello");

        const sendMessage2 = await communicationChannel.connect(user2).sendMessage(1, "Hi");
        expect(sendMessage2)
            .to.emit(communicationChannel, "MessageSent").withArgs(1, user2Address, "Hi");

        await expect(communicationChannel.connect(a2).sendMessage(1, "Hello"))
            .to.be.revertedWith("You are not involved in the contract!")
    });

    it ("Should be able to retrieve messages", async () => {
        const validProperties1 = [
            2, 2, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 4, 0, false, verificationStart];

        const setProperties = await baseContract.setGeneralRepo(2, validProperties1);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(2);

        const sendMessage = await communicationChannel
            .connect(user1).sendMessage(2, "Hello. We can start our contract discussion.");
        expect(sendMessage).to.emit(communicationChannel, "MessageSent")
            .withArgs(2, user1Address, "Hello. We can start our contract discussion.");
        const sendMessage2 = await communicationChannel
            .connect(user2).sendMessage(2, "Hi. I am ready to start.");
        expect(sendMessage2).to.emit(communicationChannel, "MessageSent")
            .withArgs(2, user2Address, "Hi. I am ready to start.");
        const sendMessage3 = await communicationChannel
            .connect(user1).sendMessage(2, "Great. What is your preferred paid?");
        expect(sendMessage3).to.emit(communicationChannel, "MessageSent")
            .withArgs(2, user1Address, "Great. What is your preferred paid?");
        const sendMessage4 = await communicationChannel
            .connect(user2).sendMessage(2, "I am thinking of 10 ETH.");
        expect(sendMessage4).to.emit(communicationChannel, "MessageSent")
            .withArgs(2, user2Address, "I am thinking of 10 ETH.");
        const sendMessage5 = await communicationChannel
            .connect(user1).sendMessage(2, "That is too much. I can only afford 5 ETH.");
        expect(sendMessage5).to.emit(communicationChannel, "MessageSent")
            .withArgs(2, user1Address, "That is too much. I can only afford 5 ETH.");
        const sendMessage6 = await communicationChannel
            .connect(user2).sendMessage(2, "I can only go down to 8 ETH.");
        expect(sendMessage6).to.emit(communicationChannel, "MessageSent")
            .withArgs(2, user2Address, "I can only go down to 8 ETH.");
        const sendMessage7 = await communicationChannel
            .connect(user1).sendMessage(2, "Deal! Let's start.");
        expect(sendMessage7).to.emit(communicationChannel, "MessageSent")
            .withArgs(2, user1Address, "Deal! Let's start.");
        const sendMessage8 = await communicationChannel
            .connect(user2).sendMessage(2, "Great!");
        expect(sendMessage8).to.emit(communicationChannel, "MessageSent")
            .withArgs(2, user2Address, "Great!");

        const expectedMessages = 
            "Payer: Hello. We can start our contract discussion.\n"
            + "Payee: Hi. I am ready to start.\n"
            + "Payer: Great. What is your preferred paid?\n"
            + "Payee: I am thinking of 10 ETH.\n"
            + "Payer: That is too much. I can only afford 5 ETH.\n"
            + "Payee: I can only go down to 8 ETH.\n"
            + "Payer: Deal! Let's start.\n"
            + "Payee: Great!\n"
        ;
        const messages = await communicationChannel.connect(user1).retrieveMessage(2);
        const messages2 = await communicationChannel.connect(user2).retrieveMessage(2);
        expect(messages).to.equal(expectedMessages);
        expect(messages2).to.equal(messages);

        await expect(communicationChannel.connect(a2).retrieveMessage(2))
            .to.be.revertedWith("You are not involved in the contract!");
    });

    it ("Messaging on inactivate contract should be freeze", async () => {
        const creationTime = Math.floor(Date.now() / 1000) - 9000;
        const verificationStart = Math.floor(Date.now() / 1000) - 6000;
        const string1 = web3.utils.padLeft(web3.utils.fromAscii("ad1"), 64);
        const string2 = web3.utils.padLeft(web3.utils.fromAscii("ad2"), 64);

        const validProperties1 = [
            3, 5, creationTime, 0, 0, [user1Address, string1, user2Address, string2, 2],
            1, 8, 4, 0, false, verificationStart];

        const setProperties = await baseContract.setGeneralRepo(3, validProperties1);
        expect(setProperties).to.emit(baseContract, "PropertiesRecorded").withArgs(3);

        await expect(communicationChannel.connect(user1).sendMessage(3, "Hello"))
            .to.be.revertedWith("The contract is inactivated!");
    });
});