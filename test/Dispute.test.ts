import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Dispute v1 contract test", function () {
  async function disputeFixture() {
    const [
      initiator,
      respondent,
      contractAddress,
      externalParty,
      voter1,
      voter2,
      voter3,
    ] = await ethers.getSigners();

    const trustScore = await ethers.deployContract("TrustScore", [250]);

    const dispute = await ethers.deployContract("Dispute", [
      contractAddress, // dummy address for testing purposes
      trustScore,
      respondent.address,
      "Dispute test",
      "This is a dispute test",
    ]);

    // Approve Dispute contract address to allow it to call TrustScore.sol functions
    await trustScore.approveAddress(dispute.getAddress());

    // Initiate trust scores for initiator and respondent
    const defaultTrustScore = await trustScore.defaultTrustScore();
    await trustScore.setTrustScore(initiator, defaultTrustScore);
    await trustScore.setTrustScore(respondent, defaultTrustScore);

    return {
      dispute,
      trustScore,
      initiator,
      respondent,
      externalParty,
      voter1,
      voter2,
      voter3,
    };
  }

  describe("Dispute initiation stage", function () {
    it("dispute initiator and respondent are correctly defined", async function () {
      const { dispute, initiator, respondent } = await loadFixture(
        disputeFixture
      );

      expect(await dispute.initiator()).equals(initiator.address);
      expect(await dispute.respondent()).equals(respondent.address);
    });

    it("outcome can be submitted by initiator and respondent", async function () {
      const { dispute, respondent } = await loadFixture(disputeFixture);

      await expect(dispute.submitOutcome("initiator outcome")).not.to.be
        .reverted;
      await expect(
        dispute.connect(respondent).submitOutcome("respondent outcome")
      ).not.to.be.reverted;
    });

    it("outcome cannot be submitted by other parties", async function () {
      const { dispute, externalParty } = await loadFixture(disputeFixture);

      await expect(
        dispute.connect(externalParty).submitOutcome("external party outcome")
      ).to.be.revertedWith("Only initiator and respondent may submit outcomes");
    });

    it("outcome cannot be submitted when dispute is not in INITIATED status", async function () {
      const { dispute } = await loadFixture(disputeFixture);

      // Cancel dispute
      await dispute.cancelDispute();

      // Attempt to submit outcome
      await expect(
        dispute.submitOutcome("attempted outcome")
      ).to.be.revertedWith("Dispute must be initiated to submit outcomes");
    });

    it("dispute cannot be cancelled by non-initiator", async function () {
      const { dispute, respondent, externalParty } = await loadFixture(
        disputeFixture
      );

      await expect(
        dispute.connect(respondent).cancelDispute()
      ).to.be.revertedWith("Only initiator may cancel dispute");

      await expect(
        dispute.connect(externalParty).cancelDispute()
      ).to.be.revertedWith("Only initiator may cancel dispute");
    });
  });

  // Voting Start Fixture
  async function votingStartFixture() {
    const { dispute, initiator, respondent, externalParty } = await loadFixture(
      disputeFixture
    );

    await dispute.submitOutcome("initiator outcome");
    await dispute.connect(respondent).submitOutcome("respondent outcome");

    await expect(dispute.openVoting()).not.to.be.reverted;

    return { dispute, initiator, respondent, externalParty };
  }

  describe("Open voting", function () {
    it("start voting stage successfully", async function () {
      await loadFixture(votingStartFixture);
    });

    it("voting stage cannot be started if respondent outcome is not submitted", async function () {
      // Initiator outcome submitted, respondent outcome not submitted
      const { dispute } = await loadFixture(disputeFixture);
      await dispute.submitOutcome("initiator outcome");

      await expect(dispute.openVoting()).to.be.revertedWith(
        "Dispute must have outcomes submitted by initiator and respondent"
      );
    });

    it("voting stage cannot be started if initiator outcome is not submitted", async function () {
      // Initiator outcome submitted, initiator outcome not submitted
      const { dispute, respondent } = await loadFixture(disputeFixture);
      await dispute.connect(respondent).submitOutcome("respondent outcome");

      await expect(dispute.openVoting()).to.be.revertedWith(
        "Dispute must have outcomes submitted by initiator and respondent"
      );
    });

    it("voting stage cannot be started if both outcomes are not submitted", async function () {
      // Initiator outcome submitted, initiator outcome not submitted
      const { dispute } = await loadFixture(disputeFixture);

      await expect(dispute.openVoting()).to.be.revertedWith(
        "Dispute must have outcomes submitted by initiator and respondent"
      );
    });
  });

  // Voting Stage Fixture
  async function votingFixture() {
    const {
      dispute,
      trustScore,
      initiator,
      respondent,
      voter1,
      voter2,
      voter3,
    } = await loadFixture(disputeFixture);

    await dispute.submitOutcome("initiator outcome");
    await dispute.connect(respondent).submitOutcome("respondent outcome");

    await dispute.openVoting();

    // Setup TrustScore for voter1, voter2
    // voter1 - UNTRUSTED [100]
    // voter2 - NEUTRAL   [200]
    // voter3 - TRUSTED   [300]
    await expect(trustScore.setTrustScore(voter1.address, 100)).not.to.be
      .reverted;
    await expect(trustScore.setTrustScore(voter2.address, 200)).not.to.be
      .reverted;
    await expect(trustScore.setTrustScore(voter3.address, 300)).not.to.be
      .reverted;

    return {
      dispute,
      trustScore,
      initiator,
      respondent,
      voter1,
      voter2,
      voter3,
    };
  }

  // Vote weights
  const vote5 = BigInt(5);
  const vote8 = BigInt(8);
  const vote10 = BigInt(10);

  describe("Voting stage", function () {
    it("setup voting stage successfully", async function () {
      await loadFixture(votingFixture);
    });

    it("trusted user votes successfully", async function () {
      const { dispute, voter3 } = await loadFixture(votingFixture);

      await expect(dispute.connect(voter3).vote(true, vote8)).not.to.be
        .reverted;
    });

    it("untrusted users cannot vote", async function () {
      const { dispute, voter1 } = await loadFixture(votingFixture);

      await expect(
        dispute.connect(voter1).vote(true, vote5)
      ).to.be.revertedWith("Untrusted users cannot vote");
    });

    it("users stake vote out of allowed range", async function () {
      const { dispute, voter2, voter3 } = await loadFixture(votingFixture);

      // Voter 2 is NEUTRAL
      // Can only have vote weight of 5
      await expect(
        dispute.connect(voter2).vote(true, vote8)
      ).to.be.revertedWith("Score must be within given range for user tier");

      // Voter 3 is TRUSTED
      // Can only have vote weight between 5-8 inclusive
      await expect(
        dispute.connect(voter3).vote(true, vote10)
      ).to.be.revertedWith("Score must be within given range for user tier");
    });
  });

  describe("Voting conclusion", function () {
    it("Conclude votes, initiator outcome wins", async function () {
      const { dispute, trustScore, initiator, respondent, voter2, voter3 } =
        await loadFixture(votingFixture);

      // Voter 3 votes for initiator outcome
      await dispute.connect(voter3).vote(true, vote8);

      // Voter 2 votes for respondent outcome
      await dispute.connect(voter2).vote(false, vote5);

      await dispute.forceCloseVoting();

      await expect(dispute.concludeVotes()).not.to.be.reverted;

      // Check all the score changes are correct
      const defaultTrustScore = await trustScore.defaultTrustScore();

      // Initiator wins, no change in trust score
      expect(await trustScore.getTrustScore(initiator)).equals(
        defaultTrustScore
      );

      // Respondent loses, minus 50 trust score
      const respondentNewTrustScore = BigInt(defaultTrustScore) - BigInt(50);
      expect(await trustScore.getTrustScore(respondent)).equals(
        respondentNewTrustScore
      );

      // Voter 3 gains trust score equal to the amount staked (8)
      expect(await trustScore.getTrustScore(voter3)).equals(
        BigInt(300) + vote8
      );

      // Voter 2 loses trust score equal to the amount staked (5)
      expect(await trustScore.getTrustScore(voter2)).equals(
        BigInt(200) - vote5
      );

      // Final outcome should be "initiator outcome"
      expect(await dispute.getFinalOutcome()).equals("initiator outcome");
    });
  });
});
