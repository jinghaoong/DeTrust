import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Accounts contract test", function () {
  async function accountsFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const accounts = await ethers.deployContract("Accounts");
    return { accounts, owner, addr1, addr2 };
  }

  describe("Deployment", function () {
    it("one account should be present", async function () {
      const { accounts, owner } = await loadFixture(accountsFixture);

      expect(await accounts.numAccounts()).equal(1);
    });

    it("the account is owner", async function () {
      const { accounts, owner } = await loadFixture(accountsFixture);

      expect(await accounts.owner()).equals(owner.address);
    });
  });

  describe("Register accounts", function () {
    it("register accounts", async function () {
      const { accounts, addr1, addr2 } = await loadFixture(accountsFixture);

      await accounts.connect(addr1).registerAccount();
      expect(await accounts.numAccounts()).equal(2);

      await accounts.connect(addr2).registerAccount();
      expect(await accounts.numAccounts()).equal(3);
    });

    it("add accounts by owner and admin", async function () {
      const { accounts, addr1, addr2 } = await loadFixture(accountsFixture);

      await expect(accounts.addAccount(addr1)).not.to.be.reverted;
      expect(await accounts.numAccounts()).equal(2);

      // Set addr1 as ADMIN
      await accounts.setAdmin(addr1);

      await expect(accounts.connect(addr1).addAccount(addr2)).not.to.be
        .reverted;
      expect(await accounts.numAccounts()).equal(3);
    });

    it("add accounts by non-admin should throw error", async function () {
      const { accounts, addr1, addr2 } = await loadFixture(accountsFixture);

      await accounts.connect(addr1).registerAccount();
      await expect(
        accounts.connect(addr1).addAccount(addr2)
      ).to.be.revertedWith("Sender must be Admin");
    });
  });

  describe("Modifying accounts", function () {
    it("owner can call all modify functions successfully", async function () {
      const { accounts, addr1 } = await loadFixture(accountsFixture);

      await accounts.addAccount(addr1);

      await expect(accounts.setInactive(addr1)).not.to.be.reverted;
      await expect(accounts.setActive(addr1)).not.to.be.reverted;
      await expect(accounts.setModerator(addr1)).not.to.be.reverted;
      await expect(accounts.setUser(addr1)).not.to.be.reverted;
      await expect(accounts.setAdmin(addr1)).not.to.be.reverted;
    });

    it("non-admin cannot call modify functions", async function () {
      const { accounts, addr1, addr2 } = await loadFixture(accountsFixture);

      await accounts.addAccount(addr1);
      await accounts.addAccount(addr2);

      await expect(
        accounts.connect(addr1).setInactive(addr2)
      ).to.be.revertedWith("Sender must be Admin");
      await expect(accounts.connect(addr1).setActive(addr2)).to.be.revertedWith(
        "Sender must be Admin"
      );
      await expect(
        accounts.connect(addr1).setModerator(addr2)
      ).to.be.revertedWith("Sender must be Admin");
      await expect(accounts.connect(addr1).setUser(addr2)).to.be.revertedWith(
        "Sender must be Admin"
      );
      await expect(accounts.connect(addr1).setAdmin(addr2)).to.be.revertedWith(
        "Sender must be Owner"
      );

      // Set addr1 to MODERATOR
      await accounts.setModerator(addr1);

      await expect(
        accounts.connect(addr1).setInactive(addr2)
      ).to.be.revertedWith("Sender must be Admin");
      await expect(accounts.connect(addr1).setActive(addr2)).to.be.revertedWith(
        "Sender must be Admin"
      );
      await expect(
        accounts.connect(addr1).setModerator(addr2)
      ).to.be.revertedWith("Sender must be Admin");
      await expect(accounts.connect(addr1).setUser(addr2)).to.be.revertedWith(
        "Sender must be Admin"
      );
      await expect(accounts.connect(addr1).setAdmin(addr2)).to.be.revertedWith(
        "Sender must be Owner"
      );
    });
  });
});
