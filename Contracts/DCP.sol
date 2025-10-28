// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Decentralized Crowdfunding Platform
 * @dev A smart contract for creating and managing crowdfunding campaigns
 */
contract Project {
    
    // Structure to store campaign details
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool withdrawn;
        bool active;
    }
    
    // Structure to store contributor information
    struct Contribution {
        address contributor;
        uint256 amount;
    }
    
    // State variables
    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Contribution[]) public campaignContributions;
    mapping(uint256 => mapping(address => uint256)) public contributorAmounts;
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    // Modifiers
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCount, "Campaign does not exist");
        _;
    }
    
    modifier onlyCreator(uint256 _campaignId) {
        require(
            msg.sender == campaigns[_campaignId].creator,
            "Only campaign creator can call this"
        );
        _;
    }
    
    /**
     * @dev Core Function 1: Create a new crowdfunding campaign
     * @param _title Campaign title
     * @param _description Campaign description
     * @param _goalAmount Funding goal in wei
     * @param _durationInDays Campaign duration in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        campaigns[campaignCount] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            withdrawn: false,
            active: true
        });
        
        emit CampaignCreated(
            campaignCount,
            msg.sender,
            _title,
            _goalAmount,
            deadline
        );
        
        campaignCount++;
        return campaignCount - 1;
    }
    
    /**
     * @dev Core Function 2: Contribute funds to a campaign
     * @param _campaignId ID of the campaign to contribute to
     */
    function contribute(uint256 _campaignId) 
        external 
        payable 
        campaignExists(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(campaign.active, "Campaign is not active");
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be greater than 0");
        
        campaign.raisedAmount += msg.value;
        contributorAmounts[_campaignId][msg.sender] += msg.value;
        
        campaignContributions[_campaignId].push(Contribution({
            contributor: msg.sender,
            amount: msg.value
        }));
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds if campaign goal is met
     * @param _campaignId ID of the campaign
     */
    function withdrawFunds(uint256 _campaignId) 
        external 
        campaignExists(_campaignId)
        onlyCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(campaign.active, "Campaign is not active");
        require(block.timestamp >= campaign.deadline, "Campaign is still ongoing");
        require(!campaign.withdrawn, "Funds already withdrawn");
        require(
            campaign.raisedAmount >= campaign.goalAmount,
            "Goal not reached"
        );
        
        campaign.withdrawn = true;
        campaign.active = false;
        
        uint256 amount = campaign.raisedAmount;
        campaign.creator.transfer(amount);
        
        emit FundsWithdrawn(_campaignId, msg.sender, amount);
    }
    
    /**
     * @dev Request refund if campaign failed to reach goal
     * @param _campaignId ID of the campaign
     */
    function requestRefund(uint256 _campaignId) 
        external 
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(block.timestamp >= campaign.deadline, "Campaign is still ongoing");
        require(
            campaign.raisedAmount < campaign.goalAmount,
            "Campaign goal was reached"
        );
        require(!campaign.withdrawn, "Funds already withdrawn");
        
        uint256 contributedAmount = contributorAmounts[_campaignId][msg.sender];
        require(contributedAmount > 0, "No contribution found");
        
        contributorAmounts[_campaignId][msg.sender] = 0;
        payable(msg.sender).transfer(contributedAmount);
        
        emit RefundIssued(_campaignId, msg.sender, contributedAmount);
    }
    
    /**
     * @dev Get campaign details
     * @param _campaignId ID of the campaign
     */
    function getCampaignDetails(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool withdrawn,
            bool active
        )
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.withdrawn,
            campaign.active
        );
    }
    
    /**
     * @dev Get contributor's contribution amount
     * @param _campaignId ID of the campaign
     * @param _contributor Address of the contributor
     */
    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return contributorAmounts[_campaignId][_contributor];
    }
    
    /**
     * @dev Get number of contributors for a campaign
     * @param _campaignId ID of the campaign
     */
    function getContributorCount(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return campaignContributions[_campaignId].length;
    }
}
