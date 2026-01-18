export const LOCATION_DATA: Record<string, Record<string, string[]>> = {
    "United States": {
        "New York": ["New York City", "Buffalo", "Rochester", "Syracuse", "Albany"],
        "California": ["Los Angeles", "San Francisco", "San Diego", "San Jose", "Sacramento"],
        "Texas": ["Houston", "Austin", "Dallas", "San Antonio", "Fort Worth"],
        "Florida": ["Miami", "Orlando", "Tampa", "Jacksonville"],
        "Illinois": ["Chicago", "Springfield", "Peoria"]
    },
    "United Kingdom": {
        "England": ["London", "Manchester", "Birmingham", "Liverpool", "Leeds"],
        "Scotland": ["Glasgow", "Edinburgh", "Aberdeen"],
        "Wales": ["Cardiff", "Swansea", "Newport"],
        "Northern Ireland": ["Belfast", "Derry"]
    },
    "Canada": {
        "Ontario": ["Toronto", "Ottawa", "Mississauga", "Hamilton"],
        "British Columbia": ["Vancouver", "Victoria", "Surrey"],
        "Quebec": ["Montreal", "Quebec City", "Laval"],
        "Alberta": ["Calgary", "Edmonton"]
    },
    "Nigeria": {
        "Lagos": ["Ikeja", "Lekki", "Victoria Island", "Yaba", "Surulere"],
        "Abuja": ["Garki", "Wuse", "Maitama", "Asokoro"],
        "Rivers": ["Port Harcourt", "Obio-Akpor"],
        "Kano": ["Kano", "Gwale"],
        "Oyo": ["Ibadan"]
    },
    "Ghana": {
        "Greater Accra": ["Accra", "Tema", "Madina"],
        "Ashanti": ["Kumasi", "Obuasi"],
        "Central": ["Cape Coast"],
        "Western": ["Takoradi"]
    },
    "South Africa": {
        "Gauteng": ["Johannesburg", "Pretoria", "Soweto"],
        "Western Cape": ["Cape Town", "Stellenbosch"],
        "KwaZulu-Natal": ["Durban", "Pietermaritzburg"]
    },
    "Germany": {
        "Berlin": ["Berlin"],
        "Bavaria": ["Munich", "Nuremberg"],
        "Hamburg": ["Hamburg"]
    },
    "France": {
        "Île-de-France": ["Paris"],
        "Provence-Alpes-Côte d'Azur": ["Marseille", "Nice"],
        "Auvergne-Rhône-Alpes": ["Lyon"]
    }
};

export const COUNTRIES_LIST = Object.keys(LOCATION_DATA).sort();
