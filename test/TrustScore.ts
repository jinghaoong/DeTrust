import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

const defaultTrustScore = 250;

describe("TrustScore contract test", function () {
  async function trustScoreFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const trustScore = await ethers.deployContract("TrustScore", [
      defaultTrustScore,
    ]);
    return { trustScore, owner, addr1, addr2 };
  }

  describe("Deployment", function () {
    it("deployment successful", async function () {
      const { trustScore, owner, addr1 } = await loadFixture(trustScoreFixture);

      expect(await trustScore.owner()).equals(owner.address);
      expect(await trustScore.defaultTrustScore()).equals(defaultTrustScore);
    });
  });

  describe("Approve users", function () {
    it("owner can approve user", async function () {
      const { trustScore, addr1 } = await loadFixture(trustScoreFixture);

      await expect(trustScore.approveAddress(addr1)).not.to.be.reverted;
    });

    it("non-owner cannot approve other user", async function () {
      const { trustScore, addr1, addr2 } = await loadFixture(trustScoreFixture);

      await expect(
        trustScore.connect(addr1).approveAddress(addr2)
      ).to.be.revertedWith("Not contract owner!");
    });
  });

  describe("Trust score functions", function () {
    it("approved users can change default trust score", async function () {
      const { trustScore, addr1 } = await loadFixture(trustScoreFixture);

      // Owner sets default trust score to 300
      const newDefaultTrustScore = 300;
      await expect(trustScore.setDefaultTrustScore(newDefaultTrustScore)).not.to
        .be.reverted;
      expect(await trustScore.defaultTrustScore()).equals(newDefaultTrustScore);

      // addr1 sets default trust score back to 250
      await trustScore.approveAddress(addr1);
      const newDefaultTrustScore2 = 250;
      await expect(
        trustScore.connect(addr1).setDefaultTrustScore(newDefaultTrustScore2)
      ).not.to.be.reverted;
      expect(await trustScore.defaultTrustScore()).equals(
        newDefaultTrustScore2
      );
    });

    it("non-approved user cannot change default trust score", async function () {
      const { trustScore, addr1 } = await loadFixture(trustScoreFixture);

      await expect(
        trustScore.connect(addr1).setDefaultTrustScore(300)
      ).to.be.revertedWith("User not approved!");
    });

    it("set, increase and decrease trust score", async function () {
      const { trustScore, addr1 } = await loadFixture(trustScoreFixture);

      await expect(trustScore.setTrustScore(addr1, 250)).not.to.be.reverted;
      expect(await trustScore.getTrustScore(addr1)).equals(250);

      await expect(trustScore.increaseTrustScore(addr1, 50)).not.to.be.reverted;
      expect(await trustScore.getTrustScore(addr1)).equals(300);

      await expect(trustScore.decreaseTrustScore(addr1, 100)).not.to.be
        .reverted;
      expect(await trustScore.getTrustScore(addr1)).equals(200);

      // Underflow check
      await expect(trustScore.decreaseTrustScore(addr1, 201)).not.to.be
        .reverted;
      expect(await trustScore.getTrustScore(addr1)).equals(0);

      // Overflow check
      await expect(trustScore.increaseTrustScore(addr1, 501)).not.to.be
        .reverted;
      expect(await trustScore.getTrustScore(addr1)).equals(500);
    });

    it("trust score cannot be set out of the default range 0-500", async function () {
      const { trustScore, addr1 } = await loadFixture(trustScoreFixture);

      await expect(trustScore.setDefaultTrustScore(501)).to.be.revertedWith(
        "Out of default range"
      );

      await expect(trustScore.setTrustScore(addr1, 501)).to.be.revertedWith(
        "Out of default range"
      );
    });
  });
});
