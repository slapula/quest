FROM node:10
ENV NODE_ENV=production

WORKDIR /app

COPY ["package.json", "./"]

RUN npm install --production

COPY . .

CMD [ "npm", "start" ]