const { DynamoDBClient, DeleteItemCommand } = require('@aws-sdk/client-dynamodb');

const client = new DynamoDBClient({});
const TABLE_NAME = process.env.TABLE_NAME;

exports.handler = async (event) => {
  console.log('DELETE annotation request:', JSON.stringify(event));

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS'
  };

  try {
    // Get uuid from path parameter or request body
    let uuid;

    if (event.pathParameters && event.pathParameters.uuid) {
      uuid = event.pathParameters.uuid;
    } else if (event.body) {
      const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
      uuid = body.uuid;
    }

    if (!uuid) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          success: false,
          error: 'Missing required field: uuid'
        })
      };
    }

    console.log('Deleting annotation:', uuid);

    const command = new DeleteItemCommand({
      TableName: TABLE_NAME,
      Key: {
        uuid: { S: uuid }
      }
    });

    await client.send(command);

    console.log('Annotation deleted successfully:', uuid);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        message: 'Annotation deleted successfully',
        uuid: uuid
      })
    };
  } catch (error) {
    console.error('Error deleting annotation:', error);

    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        success: false,
        error: 'Failed to delete annotation',
        message: error.message
      })
    };
  }
};
