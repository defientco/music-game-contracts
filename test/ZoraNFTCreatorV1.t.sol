// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import "../src/ZoraNFTCreatorV1.sol";
import "../src/ZoraNFTCreatorProxy.sol";
import {MockMetadataRenderer} from "./metadata/MockMetadataRenderer.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";

contract ZoraNFTCreatorV1Test is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS =
        payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS =
        payable(address(0x999));
    ERC721Drop public dropImpl;
    ZoraNFTCreatorV1 public creator;
    DropMetadataRenderer public dropMetadataRenderer;

    function setUp() public {
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        dropImpl = new ERC721Drop(address(1234));
        dropMetadataRenderer = new DropMetadataRenderer();
        ZoraNFTCreatorV1 impl = new ZoraNFTCreatorV1(
            address(dropImpl),
            dropMetadataRenderer
        );
        creator = ZoraNFTCreatorV1(
            address(new ZoraNFTCreatorProxy(address(impl), ""))
        );
        creator.initialize();
    }

    function test_CreateDrop() public {
        address deployedDrop = creator.createDrop(
            "name",
            "symbol",
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            1000,
            100,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.ERC20SalesConfiguration({
                publicSaleStart: 0,
                erc20PaymentToken: address(0),
                publicSaleEnd: 0,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            "metadata_uri",
            "metadata_contract_uri"
        );
    }

    function test_CreateDropAndMint() public {
        address deployedDrop = creator.createDrop(
            "name",
            "symbol",
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            1000,
            100,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.ERC20SalesConfiguration({
                publicSaleStart: 0,
                erc20PaymentToken: address(0),
                publicSaleEnd: uint64(block.timestamp + 1),
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            "metadata_uri",
            "metadata_contract_uri"
        );

        IERC721Drop(deployedDrop).purchase(1);
        assertEq(IERC721AUpgradeable(deployedDrop).ownerOf(1), address(this));
    }

    function test_CreateGenericDrop() public {
        MockMetadataRenderer mockRenderer = new MockMetadataRenderer();
        address deployedDrop = creator.setupDropsContract(
            "name",
            "symbol",
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            1000,
            100,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.ERC20SalesConfiguration({
                publicSaleStart: 0,
                erc20PaymentToken: address(0),
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            mockRenderer,
            ""
        );
        ERC721Drop drop = ERC721Drop(payable(deployedDrop));
        vm.expectRevert(
            IERC721AUpgradeable.URIQueryForNonexistentToken.selector
        );
        drop.tokenURI(1);
        assertEq(drop.contractURI(), "DEMO");
        drop.purchase(1);
        assertEq(drop.tokenURI(1), "DEMO");
    }
}
