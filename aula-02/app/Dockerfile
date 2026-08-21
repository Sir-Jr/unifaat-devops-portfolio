FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --production

COPY . .

# Usuário não-root para rodar a aplicação
RUN addgroup -S technova && adduser -S technova -G technova
USER technova

EXPOSE 3000

CMD ["node", "app.js"]
