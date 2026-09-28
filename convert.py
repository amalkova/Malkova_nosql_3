import csv
import os

os.makedirs("import", exist_ok=True)

# movies.dat: MovieID::Title::Genres
with open("ml-1m/movies.dat", encoding="latin-1") as f_in, \
     open("import/movies.csv", "w", newline="", encoding="utf-8") as f_out:
    writer = csv.writer(f_out)
    writer.writerow(["movieId", "title", "genres"])

    for line in f_in:
        parts = line.strip().split("::")
        writer.writerow(parts)


# ratings.dat: UserID::MovieID::Rating::Timestamp
with open("ml-1m/ratings.dat", encoding="latin-1") as f_in, \
     open("import/ratings.csv", "w", newline="", encoding="utf-8") as f_out:
    writer = csv.writer(f_out)
    writer.writerow(["userId", "movieId", "rating", "timestamp"])

    for line in f_in:
        parts = line.strip().split("::")
        writer.writerow(parts)


# users.dat: UserID::Gender::Age::Occupation::Zip
with open("ml-1m/users.dat", encoding="latin-1") as f_in, \
     open("import/users.csv", "w", newline="", encoding="utf-8") as f_out:
    writer = csv.writer(f_out)
    writer.writerow(["userId", "gender", "age", "occupation"])

    for line in f_in:
        parts = line.strip().split("::")
        writer.writerow(parts[:4])

print("Conversion completed.")
