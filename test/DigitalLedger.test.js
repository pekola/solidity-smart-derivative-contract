const { expect } = require("chai");

describe("DigitalLedger", () => {
  it("Should construct a digital ledger and mint tokens", async () => {
    const [owner, counterparty1, counterparty2] = await ethers.getSigners();
    const DigitalLedgerFactory = await ethers.getContractFactory("DigitalLedger");
    const digitalLedger = await DigitalLedgerFactory.deploy(owner.address,"TokenSample","XXX");
    await digitalLedger.deployed();
    expect(await digitalLedger.totalSupply()).to.equal(0);
    await digitalLedger.connect(owner).mint(counterparty1.address, 5);
    await digitalLedger.connect(owner).mint(counterparty2.address, 10);
    await digitalLedger.connect(counterparty2).transferFrom(counterparty2.address,counterparty1.address,5);
    expect(await digitalLedger.totalSupply()).to.equal(15);
    expect(await digitalLedger.connect(counterparty2).balanceOf(counterparty2.address)).to.equal(5);
    expect(await digitalLedger.connect(counterparty1).balanceOf(counterparty1.address)).to.equal(10);
  });
});