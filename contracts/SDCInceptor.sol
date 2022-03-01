// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SDC.sol";

contract SDCInceptor {
    address[] private registeredSDCAdresses;

    constructor(){

    }

 /**   function exists(address sdc_address) public returns (bool) {
       return false;// return registeredSDCAdresses[sdc_address] != address(0);
    }
*/

    event SDCCreated(address cp1, address cp2);

    
    function createSDC(address cp1, address cp2, address bufferToken) external returns (address){
        bytes20  id = ripemd160(abi.encodePacked(cp1,cp2,bufferToken));

 //       if ( this.exists(id) ){
            SDC sdc = new SDC(id,cp1,cp2,bufferToken);
            address sdc_addr = address(sdc);
            registeredSDCAdresses.push(sdc_addr);
            emit SDCCreated(cp1,cp2);
//        }
        return sdc_addr;
    }

    
    


}
