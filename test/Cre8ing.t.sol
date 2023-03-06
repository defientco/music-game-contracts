// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {Cre8ing} from "../src/Cre8ing.sol";
import {ERC721MusicGame} from "../src/ERC721MusicGame.sol";
import {DummyMetadataRenderer} from "./utils/DummyMetadataRenderer.sol";
import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract Cre8ingTest is Test {
    Cre8ing public cre8ingBase;
    ERC721MusicGame public ERC721MusicGameNFTBase;
    DummyMetadataRenderer public dummyRenderer = new DummyMetadataRenderer();

    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address public constant DEFAULT_CRE8OR_ADDRESS = address(456);
    address public constant DEFAULT_TRANSFER_ADDRESS = address(0x2);

    function setUp() public {
        cre8ingBase = new Cre8ing(DEFAULT_OWNER_ADDRESS);
    }

    modifier setupERC721MusicGameNFTBase() {
        ERC721MusicGameNFTBase = new ERC721MusicGame({
            _contractName: "ERC721MusicGame",
            _contractSymbol: "CRE8",
            _initialOwner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_OWNER_ADDRESS),
            _editionSize: 10_000,
            _royaltyBPS: 808,
            _metadataRenderer: dummyRenderer,
            _salesConfig: IERC721Drop.ERC20SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: uint64(block.timestamp + 1000),
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0),
                erc20PaymentToken: address(0)
            })
        });

        _;
    }

    function test_cre8ingPeriod(uint256 _tokenId) public {
        (bool cre8ing, uint256 current, uint256 total) = cre8ingBase
            .cre8ingPeriod(_tokenId);
        assertTrue(!cre8ing);
        assertEq(current, 0);
        assertEq(total, 0);
    }

    function test_cre8ingOpen() public {
        assertTrue(!cre8ingBase.cre8ingOpen());
    }

    function test_setCre8ingOpenReverts_AdminAccess_MissingRoleOrAdmin(
        bool _isOpen
    ) public {
        assertTrue(!cre8ingBase.cre8ingOpen());
        bytes32 role = cre8ingBase.SALES_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature(
                "AdminAccess_MissingRoleOrAdmin(bytes32)",
                role
            )
        );
        cre8ingBase.setCre8ingOpen(_isOpen);
        assertTrue(!cre8ingBase.cre8ingOpen());
    }

    function test_setCre8ingOpen(bool _isOpen) public {
        assertTrue(!cre8ingBase.cre8ingOpen());
        vm.prank(DEFAULT_OWNER_ADDRESS);
        cre8ingBase.setCre8ingOpen(_isOpen);
        assertTrue(
            _isOpen ? cre8ingBase.cre8ingOpen() : !cre8ingBase.cre8ingOpen()
        );
    }

    function test_toggleCre8ingRevert_OwnerQueryForNonexistentToken(
        uint256 _tokenId
    ) public setupERC721MusicGameNFTBase {
        (bool cre8ing, uint256 current, uint256 total) = ERC721MusicGameNFTBase
            .cre8ingPeriod(_tokenId);
        assertTrue(!cre8ing);
        assertEq(current, 0);
        assertEq(total, 0);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        vm.expectRevert(
            abi.encodeWithSignature("OwnerQueryForNonexistentToken()")
        );
        ERC721MusicGameNFTBase.toggleCre8ing(tokenIds);
    }

    function test_toggleCre8ingRevert_Cre8ing_Cre8ingClosed()
        public
        setupERC721MusicGameNFTBase
    {
        uint256 _tokenId = 1;
        (bool cre8ing, uint256 current, uint256 total) = ERC721MusicGameNFTBase
            .cre8ingPeriod(_tokenId);
        assertTrue(!cre8ing);
        assertEq(current, 0);
        assertEq(total, 0);
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        ERC721MusicGameNFTBase.purchase(1, initData);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        vm.expectRevert(abi.encodeWithSignature("Cre8ing_Cre8ingClosed()"));
        ERC721MusicGameNFTBase.toggleCre8ing(tokenIds);
    }

    function test_toggleCre8ing() public setupERC721MusicGameNFTBase {
        uint256 _tokenId = 1;
        (bool cre8ing, uint256 current, uint256 total) = ERC721MusicGameNFTBase
            .cre8ingPeriod(_tokenId);
        assertTrue(!cre8ing);
        assertEq(current, 0);
        assertEq(total, 0);
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        ERC721MusicGameNFTBase.purchase(1, initData);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        ERC721MusicGameNFTBase.setCre8ingOpen(true);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        ERC721MusicGameNFTBase.toggleCre8ing(tokenIds);
        (cre8ing, current, total) = ERC721MusicGameNFTBase.cre8ingPeriod(
            _tokenId
        );
        assertTrue(cre8ing);
        assertEq(current, 0);
        assertEq(total, 0);
    }

    function test_blockCre8ingTransfer() public setupERC721MusicGameNFTBase {
        uint256 _tokenId = 1;
        vm.prank(DEFAULT_CRE8OR_ADDRESS);
        uint256[] memory initSamples = new uint256[](0);
        // metadata for new mix
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        ERC721MusicGameNFTBase.purchase(1, initData);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        ERC721MusicGameNFTBase.setCre8ingOpen(true);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        vm.startPrank(DEFAULT_CRE8OR_ADDRESS);
        ERC721MusicGameNFTBase.toggleCre8ing(tokenIds);
        vm.expectRevert(abi.encodeWithSignature("Cre8ing_Cre8ing()"));
        ERC721MusicGameNFTBase.safeTransferFrom(
            DEFAULT_CRE8OR_ADDRESS,
            DEFAULT_OWNER_ADDRESS,
            _tokenId
        );
    }

    function test_safeTransferWhileCre8ing()
        public
        setupERC721MusicGameNFTBase
    {
        uint256 _tokenId = 1;
        vm.prank(DEFAULT_CRE8OR_ADDRESS);
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        ERC721MusicGameNFTBase.purchase(1, initData);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        ERC721MusicGameNFTBase.setCre8ingOpen(true);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        vm.startPrank(DEFAULT_CRE8OR_ADDRESS);
        ERC721MusicGameNFTBase.toggleCre8ing(tokenIds);
        assertEq(
            ERC721MusicGameNFTBase.ownerOf(_tokenId),
            DEFAULT_CRE8OR_ADDRESS
        );
        ERC721MusicGameNFTBase.safeTransferWhileCre8ing(
            DEFAULT_CRE8OR_ADDRESS,
            DEFAULT_TRANSFER_ADDRESS,
            _tokenId
        );
        assertEq(
            ERC721MusicGameNFTBase.ownerOf(_tokenId),
            DEFAULT_TRANSFER_ADDRESS
        );
        (bool cre8ing, , ) = ERC721MusicGameNFTBase.cre8ingPeriod(_tokenId);
        assertTrue(cre8ing);
    }

    function test_safeTransferWhileCre8ingRevert_Access_OnlyOwner()
        public
        setupERC721MusicGameNFTBase
    {
        uint256 _tokenId = 1;
        vm.prank(DEFAULT_CRE8OR_ADDRESS);
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        ERC721MusicGameNFTBase.purchase(1, initData);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        ERC721MusicGameNFTBase.setCre8ingOpen(true);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        vm.prank(DEFAULT_CRE8OR_ADDRESS);
        ERC721MusicGameNFTBase.toggleCre8ing(tokenIds);
        assertEq(
            ERC721MusicGameNFTBase.ownerOf(_tokenId),
            DEFAULT_CRE8OR_ADDRESS
        );
        vm.startPrank(DEFAULT_TRANSFER_ADDRESS);
        vm.expectRevert(abi.encodeWithSignature("Access_OnlyOwner()"));
        ERC721MusicGameNFTBase.safeTransferWhileCre8ing(
            DEFAULT_CRE8OR_ADDRESS,
            DEFAULT_TRANSFER_ADDRESS,
            _tokenId
        );
        assertEq(
            ERC721MusicGameNFTBase.ownerOf(_tokenId),
            DEFAULT_CRE8OR_ADDRESS
        );
    }

    function test_expelFromWarehouseRevert_uncre8ed()
        public
        setupERC721MusicGameNFTBase
    {
        uint256 _tokenId = 1;
        vm.prank(DEFAULT_CRE8OR_ADDRESS);
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        ERC721MusicGameNFTBase.purchase(1, initData);

        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        ERC721MusicGameNFTBase.setCre8ingOpen(true);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        bytes32 role = cre8ingBase.EXPULSION_ROLE();
        ERC721MusicGameNFTBase.grantRole(role, DEFAULT_OWNER_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSignature("CRE8ING_NotCre8ing(uint256)", _tokenId)
        );
        ERC721MusicGameNFTBase.expelFromWarehouse(_tokenId);
    }

    function test_expelFromWarehouseRevert_AccessControl()
        public
        setupERC721MusicGameNFTBase
    {
        uint256 _tokenId = 1;
        vm.prank(DEFAULT_CRE8OR_ADDRESS);
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        ERC721MusicGameNFTBase.purchase(1, initData);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        ERC721MusicGameNFTBase.setCre8ingOpen(true);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        vm.prank(DEFAULT_CRE8OR_ADDRESS);
        ERC721MusicGameNFTBase.toggleCre8ing(tokenIds);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        (bool cre8ing, , ) = ERC721MusicGameNFTBase.cre8ingPeriod(_tokenId);
        assertTrue(cre8ing);
        bytes32 role = cre8ingBase.EXPULSION_ROLE();
        vm.startPrank(DEFAULT_CRE8OR_ADDRESS);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(DEFAULT_CRE8OR_ADDRESS),
                " is missing role ",
                Strings.toHexString(uint256(role), 32)
            )
        );
        ERC721MusicGameNFTBase.expelFromWarehouse(_tokenId);
        (cre8ing, , ) = ERC721MusicGameNFTBase.cre8ingPeriod(_tokenId);
        assertTrue(cre8ing);
    }

    function test_expelFromWarehouse() public setupERC721MusicGameNFTBase {
        uint256 _tokenId = 1;
        vm.prank(DEFAULT_CRE8OR_ADDRESS);
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        ERC721MusicGameNFTBase.purchase(1, initData);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        ERC721MusicGameNFTBase.setCre8ingOpen(true);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        vm.prank(DEFAULT_CRE8OR_ADDRESS);
        ERC721MusicGameNFTBase.toggleCre8ing(tokenIds);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        bytes32 role = ERC721MusicGameNFTBase.EXPULSION_ROLE();
        ERC721MusicGameNFTBase.grantRole(role, DEFAULT_OWNER_ADDRESS);
        (bool cre8ing, , ) = ERC721MusicGameNFTBase.cre8ingPeriod(_tokenId);
        assertTrue(cre8ing);
        ERC721MusicGameNFTBase.expelFromWarehouse(_tokenId);
        (cre8ing, , ) = ERC721MusicGameNFTBase.cre8ingPeriod(_tokenId);
        assertTrue(!cre8ing);
    }
}
