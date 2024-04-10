const axios = require("axios");

exports.handler = async (event) => {
  console.log("Event: ", event);
  let responseMessage = "Hello, World!!!";
  const body = JSON.parse(event.body);

  const token =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6InRlc3QtdXNlci1pZCIsImFwcElkIjoiZ3ZNQmcycmZNQi13bjVCNE1nS01VIiwicGVybWlzc2lvbnMiOlsiZ2V0TG9hbnNCeUxlbmRlck5hbWVPckNvZGUiXSwiaWF0IjoxNzEyNjM0MzQxLCJleHAiOjE3MTI3MjA3NDF9.jjRgs3UG1F8mkTZFUfkWrD97exdA8nGkpzfNUK7T5Hc";

  const graphqlQuery = `
  query GetLoansByLenderNameOrCode($searchInput: String) {
    getLoansByLenderNameOrCode(searchInput: $searchInput) {
      _id
      lender
      borrower
      firstName
      lastName
      status
      lastPaidInstallmentDate
    }
  }
  `;

  const variables = {
    searchInput: "",
  };

  try {
    const graphqlResponse = await axios.post(
      "https://int-universal-federation-testing.vercel.app/graphql",
      {
        query: graphqlQuery,
        variables: variables,
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
      }
    );

    console.log("GraphQL Response: ", graphqlResponse.data);

    const response = {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          query: body.Detail.graphqlQuery,
          variables: body.Detail.variables,
        },
        graphqlData: graphqlResponse.data,
      }),
    };

    return response;
  } catch (error) {
    console.error("Error sending GraphQL request: ", error);

    const errorResponse = {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        error: "Error sending GraphQL request",
      }),
    };

    return errorResponse;
  }
};
