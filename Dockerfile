FROM node:10.14.2-alpine

COPY package.json ./
RUN npm install

COPY src src

EXPOSE 3002

CMD ["npm", "start"]
