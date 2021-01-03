pragma solidity ^0.6.7;

interface GemLike {
    function approve(address, uint) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
}

interface DaiJoinLike {
    function vat() external returns (VatLike);
    function dai() external returns (GemLike);
    function join(address, uint) external payable;
    function exit(address, uint) external;
}

interface VatLike {
    function can(address, address) external view returns (uint);
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);
    function dai(address) external view returns (uint);
    function urns(bytes32, address) external view returns (uint, uint);
    function frob(bytes32, address, address, address, int, int) external;
    function hope(address) external;
    function move(address, address, uint) external;
}

interface GemJoinLike {
    function dec() external returns (uint);
    function gem() external returns (GemLike);
    function join(address, uint) external payable;
    function exit(address, uint) external;
}

interface OasisLike {
    function sellAllAmount(address pay_gem, uint pay_amt, address buy_gem, uint min_fill_amount) external returns (uint);
}

interface ManagerLike {
    function cdpCan(address, uint, address) external view returns (uint);
    function ilks(uint) external view returns (bytes32);
    function owns(uint) external view returns (address);
    function urns(uint) external view returns (address);
    function vat() external view returns (address);
    function open(bytes32) external returns (uint);
    function give(uint, address) external;
    function cdpAllow(uint, address, uint) external;
    function urnAllow(address, uint) external;
    function frob(uint, int, int) external;
    function flux(uint, address, uint) external;
    function move(uint, address, uint) external;
    function exit(address, uint, address, uint) external;
    function quit(uint, address) external;
    function enter(address, uint) external;
    function shift(uint, uint) external;
}

// wad - quantity of tokens usually with 18 decimals
// gem - collateral tokens
// vat - vault engine
// urn - a specific vault (int - collateral balance, art - stablecoin debt thats outstanding)
// .frob() - modify a vault (wipe, dink, free, draw etc)
// dart - tokens to exchange

contract Delev {
  function _getWipeDart(
    address vat,
    uint dai,
    address urn,
    bytes32 ilk
  ) internal view returns (int dat) {
      // g ets the rate from the vat
      (, uint rate,,,) = VatLike(vat).ilks(ilk);
      // get actual art val from the urn
      (, uint art) = VatLike(vat).urns(ilk, urn);
      dart = int(dat / rate);
      // check if valulated dart is not higher than urn.art (total debt) else use the val
      dart - uint(dart) <= art ? - dart : int(art);
  }

  function wipeWithEth(
    address manager, // cdp manager address
    address ethJoin, // makerdao eth adapter
    address daiJoin, // makerdao dai adapter
    address oasisMatchingMarket, // address of oasis matching contract
    uint cdp, // cdp identifier
    uint wadEth // eth amount
  ) public {
      require(wadEth > 0); // make sure a nonzero amount of eth is being removed
      address urn = ManagerLike(manager).urns(cdp); // urn pointer for the vault
      ManagerLike(manager).frob(cdp, -int(wadEth), int(0)); // Remove WETH from the vault
      ManagerLike(manager).flux(cdp, address(this), wadEth); // Move et from CDP to proxy account
      GemJoinLike(ethJoin).exit(address(this), wadEth); // Exit WETH to proxy as a token
      // --- State: ETH ewithdrawn from vault, but we are undercollateralized --> results in a revert
      GemJoinLike(ethJoin).gem().approve(oasisMatchingMarket, wadEth); // approve oasis to retrieve your eth
      uint daiAmt = OasisLike(oasisMatchingMarket).sellAllAmount( // Market order to sell all the WETH -> DAI
          address(GemJoinLike(ethJoin).gem()),
          wadEth,
          address(DaiJoinLike(daiJoin).dai()),
          uint(0)
      )
      // TODO: Use oracles instead of market selling
      // --- State: ETH withdrawn, market sold for DAI
      DaiJoinLike(daiJoin).dai().approve(daiJoin, daiAmt); // approve dai a dapterto take our DAI
      DaiJoinLike(daiJoin).join(urn, daiAmt); // call join to send DAI into the vault
      int dart = _getWipeDart(ManagerLike(manager).vat(), VatLike(ManagerLike(manager).vat()).dai(urn), urn, ManagerLike(manager).ilks(cdp));
      ManagerLike(manager).frob(cdp, int(0), dart)
  }
}
