const { expect } = require("chai");

/** 
describe("SDC Inception", () => {
 
  it("Initiates an SDC Object", async () => {
    const [tokenManager, counterparty1, counterparty2] = await ethers.getSigners();
    const DigitalLedgerFactory = await ethers.getContractFactory("DigitalLedger");
    const digitalLedger = await DigitalLedgerFactory.deploy(tokenManager.address,"TokenSample","XXX");
    await digitalLedger.deployed();
    await digitalLedger.connect(tokenManager).mint(counterparty1.address, 1000);
    await digitalLedger.connect(tokenManager).mint(counterparty2.address, 1000);

    const id = ethers.utils.ripemd160(ethers.utils.toUtf8Bytes("test"));
    console.log('SDC Id: %s',id);
    const SDCFact = await ethers.getContractFactory("SDC");
    
    const sdc_contract = await SDCFact.deploy(id,counterparty1.address,counterparty2.address,digitalLedger.address);
    await sdc_contract.deployed();
   
    console.log('SDC Adress: %s',sdc_contract.address);

    await sdc_contract.connect(counterparty1).setMarginBufferAmount(100);
    await sdc_contract.connect(counterparty1).setTerminationFeeAmount(50);
    await sdc_contract.connect(counterparty2).setMarginBufferAmount(200);
    await sdc_contract.connect(counterparty2).setTerminationFeeAmount(100);

    expect(await digitalLedger.connect(counterparty1).allowance(counterparty1.address,sdc_contract.address)).to.equal(150);
    expect(await digitalLedger.connect(counterparty2).allowance(counterparty2.address,sdc_contract.address)).to.equal(300);

    const trade_id =  await sdc_contract.connect(counterparty1).inceptTrade("fpml_data",counterparty1.address);
    await sdc_contract.connect(counterparty2).confirmTrade(trade_id);
    
    expect(await digitalLedger.connect(counterparty1).balanceOf(counterparty1.address)).to.equal(850);
    expect(await digitalLedger.connect(counterparty1).balanceOf(sdc_contract.address)).to.equal(450);

  });
});

*/