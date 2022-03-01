const { expect } = require("chai");

describe("DigitalLedger", () => {
  it("Constructs a digital ledger", async () => {
    const DigitalLedgerFactory = await ethers.getContractFactory("DigitalLedger");
    const digitalLedger = await DigitalLedgerFactory.deploy("TokenSample","XXX");
    await digitalLedger.deployed();
    expect(await digitalLedger.totalSupply()).to.equal(0);

  });

});