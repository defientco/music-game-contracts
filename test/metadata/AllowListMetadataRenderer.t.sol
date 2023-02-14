// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {AllowListMetadataRenderer} from "../../src/metadata/AllowListMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "../../src/metadata/MetadataRenderAdminCheck.sol";
import {IMetadataRenderer} from "../../src/interfaces/IMetadataRenderer.sol";
import {DropMockBase} from "./DropMockBase.sol";
import {IERC721Drop} from "../../src/interfaces/IERC721Drop.sol";
import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

contract IERC721OnChainDataMock {
    IERC721Drop.ERC20SaleDetails private saleDetailsInternal;
    IERC721Drop.Configuration private configInternal;

    constructor(uint256 totalMinted, uint256 maxSupply) {
        saleDetailsInternal = IERC721Drop.ERC20SaleDetails({
            erc20PaymentToken: address(0),
            publicSaleActive: false,
            presaleActive: false,
            publicSalePrice: 0,
            publicSaleStart: 0,
            publicSaleEnd: 0,
            presaleStart: 0,
            presaleEnd: 0,
            presaleMerkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000,
            maxSalePurchasePerAddress: 0,
            totalMinted: totalMinted,
            maxSupply: maxSupply
        });

        configInternal = IERC721Drop.Configuration({
            metadataRenderer: IMetadataRenderer(address(0x0)),
            editionSize: 12,
            royaltyBPS: 1000,
            fundsRecipient: payable(address(0x163))
        });
    }

    function name() external returns (string memory) {
        return "MOCK NAME";
    }

    function saleDetails()
        external
        returns (IERC721Drop.ERC20SaleDetails memory)
    {
        return saleDetailsInternal;
    }

    function config() external returns (IERC721Drop.Configuration memory) {
        return configInternal;
    }
}

contract AllowListMetadataRendererTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);
    address public constant mediaContract = address(123456);
    AllowListMetadataRenderer public allowListRenderer =
        new AllowListMetadataRenderer();

    function test_EditionMetadataInits() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4",
            "i love web3"
        );
        allowListRenderer.initializeWithData(data);
        (
            string memory description,
            string memory imageURI,
            string memory animationURI,
            string memory formResponse
        ) = allowListRenderer.tokenInfos(address(0x123));
        assertEq(description, "Description for metadata");
        assertEq(animationURI, "https://example.com/animation.mp4");
        assertEq(imageURI, "https://example.com/image.png");
        assertEq(formResponse, "i love web3");
    }

    function test_UpdateDescriptionAllowed() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4",
            "i love web3"
        );
        allowListRenderer.initializeWithData(data);

        allowListRenderer.updateDescription(address(0x123), "new description");

        (string memory updatedDescription, , , ) = allowListRenderer.tokenInfos(
            address(0x123)
        );
        assertEq(updatedDescription, "new description");
    }

    function test_UpdateDescriptionNotAllowed() public {
        DropMockBase base = new DropMockBase();
        vm.startPrank(address(base));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4",
            "i love web3"
        );
        allowListRenderer.initializeWithData(data);
        vm.stopPrank();

        vm.expectRevert(MetadataRenderAdminCheck.Access_OnlyAdmin.selector);
        allowListRenderer.updateDescription(address(base), "new description");
    }

    function test_AllowMetadataURIUpdates() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4",
            "i love web3"
        );
        allowListRenderer.initializeWithData(data);

        allowListRenderer.updateMediaURIs(
            address(0x123),
            "https://example.com/image.png",
            "https://example.com/animation.mp4"
        );
        allowListRenderer.initializeWithData(data);
        (
            string memory description,
            string memory imageURI,
            string memory animationURI,
            string memory formResponse
        ) = allowListRenderer.tokenInfos(address(0x123));
        assertEq(description, "Description for metadata");
        assertEq(animationURI, "https://example.com/animation.mp4");
        assertEq(imageURI, "https://example.com/image.png");
        assertEq(formResponse, "i love web3");
    }

    function test_MetadatURIUpdateNotAllowed() public {
        DropMockBase base = new DropMockBase();
        vm.startPrank(address(base));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4",
            "i love web3"
        );
        allowListRenderer.initializeWithData(data);
        vm.stopPrank();

        vm.prank(address(0x144));
        vm.expectRevert(MetadataRenderAdminCheck.Access_OnlyAdmin.selector);
        allowListRenderer.updateMediaURIs(
            address(base),
            "https://example.com/image.png",
            "https://example.com/animation.mp4"
        );
    }

    function test_MetadataRenderingURI() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({
            totalMinted: 10,
            maxSupply: 100
        });
        vm.startPrank(address(mock));
        allowListRenderer.initializeWithData(
            abi.encode("Description", "image", "animation", "formResponse")
        );
        // '{"name": "MOCK NAME 1/100", "description": "Description", "image": "image", "animation_url": "animation", "properties": {"number": 1, "name": "MOCK NAME"}}'
        assertEq(
            "data:application/json;base64,eyJuYW1lIjogIk1PQ0sgTkFNRSAxLzEwMCIsICJkZXNjcmlwdGlvbiI6ICJEZXNjcmlwdGlvbiIsICJpbWFnZSI6ICJpbWFnZSIsICJhbmltYXRpb25fdXJsIjogImFuaW1hdGlvbiIsICJwcm9wZXJ0aWVzIjogeyJudW1iZXIiOiAxLCAibmFtZSI6ICJNT0NLIE5BTUUifX0=",
            allowListRenderer.tokenURI(1)
        );
    }

    function test_OpenEdition() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({
            totalMinted: 10,
            maxSupply: type(uint64).max
        });
        vm.startPrank(address(mock));
        allowListRenderer.initializeWithData(
            abi.encode("Description", "image", "animation", "formResponse")
        );
        // {"name": "MOCK NAME 1", "description": "Description", "image": "image", "animation_url": "animation", "properties": {"number": 1, "name": "MOCK NAME"}}
        assertEq(
            "data:application/json;base64,eyJuYW1lIjogIk1PQ0sgTkFNRSAxIiwgImRlc2NyaXB0aW9uIjogIkRlc2NyaXB0aW9uIiwgImltYWdlIjogImltYWdlIiwgImFuaW1hdGlvbl91cmwiOiAiYW5pbWF0aW9uIiwgInByb3BlcnRpZXMiOiB7Im51bWJlciI6IDEsICJuYW1lIjogIk1PQ0sgTkFNRSJ9fQ==",
            allowListRenderer.tokenURI(1)
        );
    }

    function test_ContractURI() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({
            totalMinted: 20,
            maxSupply: 10
        });
        vm.startPrank(address(mock));
        allowListRenderer.initializeWithData(
            abi.encode(
                "Description",
                "ipfs://image",
                "ipfs://animation",
                "formResponse"
            )
        );
        assertEq(
            "data:application/json;base64,eyJuYW1lIjogIk1PQ0sgTkFNRSIsICJkZXNjcmlwdGlvbiI6ICJEZXNjcmlwdGlvbiIsICJzZWxsZXJfZmVlX2Jhc2lzX3BvaW50cyI6IDEwMDAsICJmZWVfcmVjaXBpZW50IjogIjB4MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDE2MyIsICJpbWFnZSI6ICJpcGZzOi8vaW1hZ2UifQ==",
            allowListRenderer.contractURI()
        );
    }
}
