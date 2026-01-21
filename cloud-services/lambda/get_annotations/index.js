const { DynamoDBClient, ScanCommand } = require('@aws-sdk/client-dynamodb');
const { unmarshall } = require('@aws-sdk/util-dynamodb');

const client = new DynamoDBClient({});
const TABLE_NAME = process.env.TABLE_NAME;

exports.handler = async (event) => {
  console.log('GET annotations request:', JSON.stringify(event));

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
  };

  try {
    const command = new ScanCommand({
      TableName: TABLE_NAME
    });

    const response = await client.send(command);

    // Convert DynamoDB format to regular JSON
    const annotations = response.Items ? response.Items.map(item => unmarshall(item)) : [];

    console.log(`Found ${annotations.length} annotations`);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        annotations
      })
    };
  } catch (error) {
    console.error('Error fetching annotations:', error);

    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        success: false,
        error: 'Failed to fetch annotations',
        message: error.message
      })
    };
  }
};
