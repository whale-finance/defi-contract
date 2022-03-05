// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./openzeppelin/IERC20.sol";
import "./openzeppelin/SafeMath.sol";
import "./openzeppelin/Ownable.sol";

contract TaxOracle is Ownable {
    using SafeMath for uint256;

    IERC20 public main;
    IERC20 public wftm;
    address public pair;

    constructor(
        address _main,
        address _wftm, 
        address _pair
    ) public {
        require(_main != address(0), "main address cannot be 0");
        require(_wftm != address(0), "wftm address cannot be 0");
        require(_pair != address(0), "pair address cannot be 0");
        main = IERC20(_main);
        wftm = IERC20(_wftm);
        pair = _pair;
    }

    function consult(address _token, uint256 _amountIn) external view returns (uint144 amountOut) {
        require(_token == address(main), "token needs to be main");
        uint256 mainBalance = main.balanceOf(pair);
        uint256 wftmBalance = wftm.balanceOf(pair);
        return uint144(mainBalance.mul(_amountIn).div(wftmBalance));
    }

    function setMain(address _main) external onlyOwner {
        require(_main != address(0), "main address cannot be 0");
        main = IERC20(_main);
    }

    function setWftm(address _wftm) external onlyOwner {
        require(_wftm != address(0), "wftm address cannot be 0");
        wftm = IERC20(_wftm);
    }

    function setPair(address _pair) external onlyOwner {
        require(_pair != address(0), "pair address cannot be 0");
        pair = _pair;
    }



}
