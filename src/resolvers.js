const resolvers = {
  Query: {
    image(_, {input}, {models}) {
      return models.image.find(input._id)
    }
  },
  Mutation: {
    image(_, {input}, {models}) {
      return models.image.post(input)
    } 
  }
}

module.exports = resolvers