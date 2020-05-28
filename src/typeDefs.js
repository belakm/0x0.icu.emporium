const { gql } = require('apollo-server')

const typeDefs = gql`
  type User {
    email: String!
    avatar: String
    friends: [User]!
  }

  type Query {
    me: User!
  }
`

module.exports = typeDefs