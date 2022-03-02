// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DigitalLedger.sol";

contract SDC{

    enum TradeStatus{ INCEPTED, CONFIRMED, LIVE, TERMINATED }

    event TradeIncepted(string id, uint256 timestamp);
    event TradeConfirmed(string id, uint256 timestamp);
    event TradeActive(string id, uint256 timestamp);
    event SDCTerminated(uint256 timestamp);
    event SDCSettlementSuccessful(uint256 timestamp);


    struct RefTradeSpec{
        uint256 trade_timestamp;
        string  fpml_data;
        TradeStatus tradeStatus;
        address adressFixedRatePayer;   // Convention is PV = Fix - Float
        address inceptionAddress;
    }

    string private id;
    address private counterparty1Address;
    address private counterparty2Address;
    address private ledgerAddress;

    uint    settlement_timestamp;

    mapping(string => RefTradeSpec) refTradeSpecs;

    mapping(address => uint) private marginBufferAmounts;
    mapping(address => uint) private terminationFeeAmounts;

  
    constructor(string memory _id, 
                address _counterparty1Adress, 
                address _counterparty2Adress, 
                address _ledgerAddress)  {
      id = _id;
      counterparty1Address = _counterparty1Adress;
      counterparty2Address = _counterparty2Adress;   
      ledgerAddress = _ledgerAddress;
    }

    /* Modifiers */
    modifier onlyCounterparty { 
        require(msg.sender == counterparty1Address || msg.sender == counterparty2Address); _;
    }

    modifier onlyValuationOracle { 
        require(true); _;
    }

    function setMarginBufferAmount (uint amount) external onlyCounterparty returns(bool) {
        marginBufferAmounts[msg.sender] = amount;
        DigitalLedger ledger =  DigitalLedger(ledgerAddress);
        ledger.increaseAllowance(msg.sender,address(this),amount);
        return true;
    }


    function setTerminationFeeAmount (uint amount) external onlyCounterparty returns(bool) {
        terminationFeeAmounts[msg.sender] = amount;
        DigitalLedger ledger =  DigitalLedger(ledgerAddress);
        ledger.increaseAllowance(msg.sender,address(this),amount);
        return true;
    }

    function inceptTrade(string memory fpml_data, address fixPayerPartyAddress) external onlyCounterparty returns(string memory){ 
        uint256 timestamp = block.timestamp;
        string memory trade_id = string(abi.encodePacked("trade_ref_",timestamp));
        refTradeSpecs[trade_id] = RefTradeSpec(timestamp,fpml_data,TradeStatus.INCEPTED,fixPayerPartyAddress,msg.sender);
        emit TradeIncepted(trade_id,timestamp);
        return trade_id;
    }

    function confirmTrade(string memory trade_id) external onlyCounterparty  returns(bool){ 
        refTradeSpecs[trade_id].trade_timestamp = block.timestamp;
        emit TradeConfirmed(trade_id,block.timestamp);
        DigitalLedger ledger =  DigitalLedger(ledgerAddress);
        ledger.transferFrom(counterparty1Address,address(this),marginBufferAmounts[counterparty1Address]+terminationFeeAmounts[counterparty1Address]);
        ledger.transferFrom(counterparty2Address,address(this),marginBufferAmounts[counterparty2Address]+terminationFeeAmounts[counterparty2Address]);
        emit TradeActive(trade_id,block.timestamp);
        return true;
    }

    function settle() external view onlyCounterparty onlyValuationOracle returns(bool){ 
        return true;
    }

    function _performSettlement(uint256 settlement_amount, address address_of_creditor ) private returns(bool){
        require(settlement_amount > 0, "Settlement amount should be positive");
        require(address_of_creditor == counterparty1Address || address_of_creditor == counterparty2Address, "Creditor Address should be either CP1 oder CP");
        address address_of_debitor = address_of_creditor == counterparty1Address ? counterparty2Address : counterparty1Address;
        if ( marginBufferAmounts[address_of_debitor] >= settlement_amount ){
            _performTermination();
            emit SDCTerminated(block.timestamp);
        }
        else{
            DigitalLedger ledger =  DigitalLedger(ledgerAddress);
            uint256 amountToTransfer = settlement_amount - marginBufferAmounts[address_of_debitor];
            ledger.transferFrom(address_of_debitor,address(this),amountToTransfer);     // autodebit
            ledger.transferFrom(address(this),address_of_creditor,amountToTransfer);    // auto_credit
            emit SDCSettlementSuccessful(block.timestamp);
        }
        
        return true;
    }

    function _performTermination() private pure returns(bool){
        return true;
    }

}