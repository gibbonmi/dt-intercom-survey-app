FROM node:8.11.3-alpine

WORKDIR /app

COPY package.json ./

RUN npm install

COPY src src/

EXPOSE 3002

CMD ["npm", "start"]