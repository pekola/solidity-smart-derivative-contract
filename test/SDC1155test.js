const { expect } = require("chai");


describe("SDC1155 Token", () => {

  let sdc1155;
  let tokenManager;
  let counterparty1;
  let counterparty2;

  before(async () => {
    const [_tokenManager, _counterparty1, _counterparty2] = await ethers.getSigners();
    tokenManager = _tokenManager;
    counterparty1 = _counterparty1;
    counterparty2 = _counterparty2;
    const SDCER20Factory = await ethers.getContractFactory("DigitalLedger");
    sdcerc20 = await SDCER20Factory.deploy(tokenManager.address,"SDCToken","SDCT");
    await sdcerc20.deployed();
  });

  it("Token Manager mints tokens for two counterparties", async () => {
    await sdcerc20.connect(tokenManager).mint(counterparty1.address, 5);
    await sdcerc20.connect(tokenManager).mint(counterparty2.address, 10);
    expect(await sdcerc20.totalSupply()).to.equal(15);
  });

  
  it("Counterparty2 triggers a transfer to counterparty1", async () => {
    expect(await sdcerc20.totalSupply()).to.equal(15);
    await sdcerc20.connect(counterparty2).transferFrom(counterparty2.address,counterparty1.address,5);
    expect(await sdcerc20.connect(counterparty2).balanceOf(counterparty2.address)).to.equal(5);
    expect(await sdcerc20.connect(counterparty1).balanceOf(counterparty1.address)).to.equal(10);
  });
});