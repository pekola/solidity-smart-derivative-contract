const { expect } = require("chai");
const mlog = require('mocha-logger');
const util = require('util');
const AbiCoder = ethers.utils.AbiCoder;

describe("SDC functionaly as ERC1155 Token", () => {

  const abiCoder = new AbiCoder();
  const fpml_data = "<fpml><trade>test-trade</trade></fpml>";
  let sdc1155;
  let tokenManager;
  let counterparty1;
  let counterparty2;
  let trade_id;

  before(async () => {
    const [_tokenManager, _counterparty1, _counterparty2,] = await ethers.getSigners();
    tokenManager = _tokenManager;
    counterparty1 = _counterparty1;
    counterparty2 = _counterparty2;
    const SDCER20Factory = await ethers.getContractFactory("SDC1155");
    sdc1155 = await SDCER20Factory.deploy("SDCToken",counterparty1.address, counterparty2.address, tokenManager.address);
    await sdc1155.deployed();
  });

  it("Token Manager mints cash tokens for both counterparties", async () => {
    await sdc1155.connect(tokenManager).mintBufferToken(counterparty1.address, 1000);
    await sdc1155.connect(tokenManager).mintBufferToken(counterparty2.address, 2000);
    expect(await sdc1155.totalCashMinted()).to.equal(3000);
    expect(await sdc1155.balanceOf(counterparty1.address,sdc1155.CASH_BUFFER())).to.equal(1000);
    expect(await sdc1155.balanceOf(counterparty2.address,sdc1155.CASH_BUFFER())).to.equal(2000);
  });

  it("Counterparty1 incepts a trade with payer party Counterparty2", async () => {
    trade_id =  abiCoder.encode(["string","address"], [fpml_data,counterparty2.address]);
    const incept_call = await sdc1155.connect(counterparty1).inceptTrade(fpml_data, counterparty2.address, 200, 50);
    expect(incept_call).to.emit(sdc1155, "TradeIncepted");
    const {0: fpml_ret, 1: address_ret, 2: status}  = await sdc1155.getTradeRef(trade_id);
    expect(status).to.equal(0);
    expect(fpml_ret).to.equal(fpml_data);
    expect(address_ret).to.equal(counterparty2.address);
  });

  it("Counterparty1 confirms a trade", async () => {
    const confirm_call = await sdc1155.connect(counterparty2).confirmTrade(trade_id);
    await expect(confirm_call).to.emit(sdc1155, "TradeConfirmed");
    const {0: fpml_ret, 1: address_ret, 2: status}  = await sdc1155.getTradeRef(trade_id);
    expect(status).to.equal(2);
    expect(await sdc1155.balanceOf(counterparty1.address,sdc1155.CASH_BUFFER())).to.equal(1000-250);
    expect(await sdc1155.balanceOf(counterparty2.address,sdc1155.CASH_BUFFER())).to.equal(2000-250);
    expect(await sdc1155.balanceOf(sdc1155.address,sdc1155.MARGIN_BUFFER())).to.equal(400);
    expect(await sdc1155.balanceOf(sdc1155.address,sdc1155.TERMINATIONFEE())).to.equal(100);
  });


});