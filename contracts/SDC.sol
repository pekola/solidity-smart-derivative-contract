// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DigitalLedger.sol";

contract SDC{

    enum TradeStatus{ INCEPTED, CONFIRMED, LIVE, TERMINATED }

    event TradeIncepted(bytes20 id, uint256 timestamp);
    event TradeConfirmed(bytes20 id, uint256 timestamp);
    event TradeLive(bytes20 id, uint256 timestamp);
    event Terminated(uint256 timestamp);
    event Settled(uint256 timestamp);


    struct TradeSpec{
        bytes20 trade_id;
        uint256 trade_timestamp;
        string  fpml_data;
        TradeStatus tradeStatus;
        address adressFixedRatePayer;   // Convention is PV = Fix - Float
    }


    bytes20 private id;
    address private counterparty1Address;
    address private counterparty2Address;
    address private ledgerAddress;

    uint    settlement_timestamp;

    mapping(bytes20 => TradeSpec) private tradeMap; 

    mapping(address => uint) private marginBufferAmounts;
    mapping(address => uint) private terminationFeeAmounts;


  
    constructor(bytes20 _id, 
                address _counterparty1Adress, 
                address _counterparty2Adress, 
                address _ledgerAddress)  {
      id = _id;
      counterparty1Address = _counterparty1Adress;
      counterparty2Address = _counterparty2Adress;   
      ledgerAddress = 
      _ledgerAddress;
    }



    /* Modifiers */
    modifier onlyCounterparty { 
        require(msg.sender == counterparty1Address || msg.sender == counterparty2Address); _;
    }

    function setMarginBufferAmount (uint amount) onlyCounterparty external returns(bool) {
        marginBufferAmounts[msg.sender] = amount;
        DigitalLedger ledger =  DigitalLedger(ledgerAddress);
        ledger.increaseAllowance(address(this),amount);
        return true;
    }


    function setTerminationFeeAmount (uint amount) onlyCounterparty public returns(bool) {
        terminationFeeAmounts[msg.sender] = amount;
        DigitalLedger ledger =  DigitalLedger(ledgerAddress);
        ledger.increaseAllowance(address(this),amount);
        return true;
    }

    function inceptTrade(string memory _fpml_data, address _fixPayerPartyAddress)  public  returns(bytes20){ //onlyCounterparty
        bytes20  _id = ripemd160(abi.encodePacked(_fpml_data)); 
        uint256 _timestamp = block.timestamp;
        tradeMap[id] = TradeSpec(_id,_timestamp,_fpml_data,TradeStatus.INCEPTED,_fixPayerPartyAddress);
        emit TradeIncepted(_id,_timestamp);
        return _id;
    }

    function confirmTrade(bytes20 trade_id)  public returns(bytes20){ //onlyCounterparty
//        require(msg.sender != tradeMap[trade_id].inceptionAddress, "not authorised");
        tradeMap[id].trade_timestamp = block.timestamp;
        emit TradeConfirmed(trade_id,block.timestamp);

        uint256 totalAmountCP1 =marginBufferAmounts[counterparty1Address]+terminationFeeAmounts[counterparty1Address];
        uint256 totalAmountCP2 =marginBufferAmounts[counterparty2Address]+terminationFeeAmounts[counterparty2Address];
        DigitalLedger ledger =  DigitalLedger(ledgerAddress);
        require(ledger.balanceOf(counterparty1Address) >= totalAmountCP1,"CP1 Address not sufficient balance");
        require(ledger.balanceOf(counterparty1Address) >= totalAmountCP2,"CP2 Address not sufficient balance");

        ledger.transferFrom(counterparty1Address,address(this),totalAmountCP1);
        ledger.transferFrom(counterparty2Address,address(this),totalAmountCP2);

        emit TradeLive(trade_id,block.timestamp);
        return trade_id;
    }


    function settle(uint256 settlement_amount, address address_of_creditor ) onlyCounterparty public returns(bool){
        require(settlement_amount > 0, "Amount should be positive");
        require(address_of_creditor == counterparty1Address || address_of_creditor == counterparty2Address, "Creditor Address should be either CP1 oder CP");
        address address_of_debitor = address_of_creditor == counterparty1Address ? counterparty2Address : counterparty1Address;
        if ( marginBufferAmounts[address_of_debitor] >= settlement_amount ){
            emit Terminated(block.timestamp);
            // terminate
        }
        else{
            DigitalLedger ledger =  DigitalLedger(ledgerAddress);
            uint256 amountToBook = settlement_amount - marginBufferAmounts[address_of_debitor];
            ledger.transferFrom(address_of_debitor,address(this),amountToBook); // autodebit
            ledger.transferFrom(address(this),address_of_creditor,amountToBook); // auto_credit
        }
        emit Settled(block.timestamp);
        return true;
    }

}