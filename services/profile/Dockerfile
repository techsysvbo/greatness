FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Copy non-TS files to dist
COPY src/db/schema.sql ./dist/db/

EXPOSE 4001

CMD ["npm", "start"]
