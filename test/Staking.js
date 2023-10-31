const { expect } = require("chai");

describe("Staking", function () {
    describe("Events", function () {
        it("Should emit an event on pool creation", async function () {
            const Staking = await ethers.getContractFactory("Staking")
            const staking = await Staking.deploy()

            await expect(staking.createStakingPool()).to.emit(staking, "CraetePool")
        })
    })
})