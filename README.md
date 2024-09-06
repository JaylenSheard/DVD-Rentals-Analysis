# DVD Rental Analysis Project

## Project Overview
This project analyzes data from Cinema Box, a video rental company specializing in affordable DVD rentals. The company allows customers to order DVDs through their website or by visiting one of their two physical locations. Despite seemingly good business performance, a recent study from the American Customer Satisfaction Index showed a 15% decrease in customer satisfaction, primarily due to a lack of selection.

## Business Questions
The project aims to answer two main business questions:

1. What is the total number of rentals missing a return date or missing customer information?
2. What are the total number of films, total number of rentals, and total number of sales per category per store_id?

## Technical Implementation

### Database Setup
- Custom functions for data transformations (e.g., concatenating first and last names)
- Creation of detailed and summary tables:
  - `dvdstore_detailed`
  - `dvdstore_summary_rentals`
  - `dvdstore_summary_categories`

### Data Processing
- Extraction of raw data from the source database into the detailed table
- Creation of trigger functions to update summary tables automatically
- Implementation of triggers to refresh summary tables when the detailed table is updated

### Automated Reporting
- Stored procedure `refresh_reports()` to update the detailed table and, consequently, the summary tables
- Designed to run every 60 days for up-to-date reporting

## Key Features
- Data transformation and aggregation
- Automated summary table updates using triggers
- Periodic data refresh using stored procedures
- Comprehensive analysis of rental patterns, inventory, and sales across different categories and stores

## Technologies Used
- PostgreSQL

## Getting Started
1. Set up a PostgreSQL database
2. Run the SQL script to create the necessary tables, functions, and procedures
3. Execute the `refresh_reports()` procedure to populate the tables with initial data
4. Query the summary tables to get insights into the business questions

## Future Improvements
- Implement a user interface for easier data visualization
- Add more detailed analysis on customer behavior and preferences
- Integrate with a recommendation system to improve DVD selection
