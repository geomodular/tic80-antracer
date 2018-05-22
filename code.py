import argparse
import random

def encrypt(code):
    val = []
    key = []
    for a in code:
        byte = random.randint(0, 255)
        key.append(byte)
        val.append(ord(a) ^ byte)
    return val, key


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("code", help="code to be encrypted with random xor", type=str)
    args = parser.parse_args()

    print(encrypt(args.code))
