extends RefCounted
## Help pages for the Recipe Book's "Kitchen Functions" tab: C syntax lessons
## and every kitchen function, each with an explanation, a short tutorial and
## an example. Edit the text here; the book picks it up automatically.
##
## Entry: {"id", "title", "group", "level", "syntax", "about", "steps": [..], "example"}
## "level" = Restaurant Level that unlocks it (C basics are always open).

const Builtins := preload("res://systems/c_interpreter/c_builtins.gd")

const BASICS := [
	{
		"id": "main", "title": "Program shape: main()", "syntax": "void main() {\n    // steps go here\n}",
		"about": "Every staff program starts in main(). The computer runs the lines inside the { } from top to bottom, one after another. Each instruction ends with a semicolon ;",
		"steps": ["Write void main() { on the first line.", "Put one instruction per line inside the braces, ending each with ;", "Close with } and press Run."],
		"example": "void main() {\n    go_to(FRIDGE);\n    pick_up(EGG);\n    printf(\"Got an egg!\\n\");\n}",
	},
	{
		"id": "comments", "title": "Comments", "syntax": "// one line\n/* several\n   lines */",
		"about": "Comments are notes for people. The computer skips them. Use them to explain what a part of your program does.",
		"steps": ["Type // and write your note after it.", "Use /* ... */ for notes that span lines.", "Comment out a line (put // in front) to switch it off while testing."],
		"example": "void main() {\n    // Make the rice first\n    go_to(FRIDGE);\n    pick_up(RICE);\n}",
	},
	{
		"id": "variables", "title": "Variables and types", "syntax": "int count = 3;\nfloat price = 2.5;\nchar grade = 'A';\nbool done = false;",
		"about": "A variable is a named box that holds a value. int holds whole numbers, float and double hold decimals, char holds one letter, bool holds true or false. Kitchen names like EGG or GRILL are numbers too, so they fit in an int.",
		"steps": ["Pick a type: int, float, double, char or bool.", "Give it a name and (usually) a starting value: int eggs = 2;", "Change it later with =, +=, -=, ++ or --."],
		"example": "void main() {\n    int dishes = 0;\n    int food = EGG;\n    go_to(FRIDGE);\n    pick_up(food);\n    dishes++;\n    printf(\"%d\\n\", dishes);\n}",
	},
	{
		"id": "datatypes", "title": "Data types", "syntax": "int whole = 5;        // %d\nfloat price = 2.50;   // %f\ndouble exact = 2.5;   // %lf\nchar letter = 'B';    // %c",
		"about": "Every variable has a data type that decides what it can hold and which format specifier prints it. int is for whole numbers, float and double for decimals (double keeps about twice as many digits), and char for one letter.",
		"steps": ["Pick the type that fits the value: whole number, decimal or letter.", "Print it with the matching specifier: %d, %f, %lf or %c.", "A wrong specifier gives wrong output, so match them carefully."],
		"example": "void main() {\n    int eggs = 12;\n    float price = 2.5;\n    double total = eggs * price;\n    char size = 'L';\n    printf(\"%d eggs, size %c, total %lf\\n\", eggs, size, total);\n}",
	},
	{
		"id": "printf", "title": "printf: printing", "syntax": "printf(\"text %d\\n\", value);",
		"about": "printf writes text to the Output box. Placeholders are replaced by values: %d whole number, %f decimal (%.2f = 2 decimals), %c a letter, %s a kitchen name. \\n starts a new line.",
		"steps": ["Write the text in double quotes.", "Put a placeholder where a value should go.", "After the text, list the values in the same order, separated by commas."],
		"example": "void main() {\n    int served = 3;\n    float total = 3 * 30.0;\n    printf(\"Served %d, earned %.2f\\n\", served, total);\n    printf(\"Cooking at the %s\\n\", GRILL);\n}",
	},
	{
		"id": "math", "title": "Math operators", "syntax": "a + b   a - b   a * b   a / b   a % b",
		"about": "+ - * / work like a calculator. Dividing two ints drops the decimals (7 / 2 is 3). % gives the remainder (7 % 2 is 1). Use ( ) to choose what is worked out first.",
		"steps": ["Combine numbers and variables with operators.", "Store the result: int total = price * 2;", "Use += -= *= /= as short forms: total += 30;"],
		"example": "void main() {\n    int price = 30;\n    int total = price * 3;\n    total += 10;\n    printf(\"%d %d\\n\", total, total % 7);\n}",
	},
	{
		"id": "compare", "title": "Comparisons and logic", "syntax": "==  !=  <  >  <=  >=\n&&  (and)   ||  (or)   !  (not)",
		"about": "Comparisons give 1 (true) or 0 (false). Use == to compare (a single = stores a value). && needs both sides true, || needs at least one, ! flips true and false.",
		"steps": ["Compare two values: holding() == EGG", "Join tests with && or ||.", "Use the result in an if or a loop."],
		"example": "void main() {\n    int eggs = 2;\n    bool enough = eggs >= 1 && eggs <= 3;\n    printf(\"%d\\n\", enough);\n}",
	},
	{
		"id": "booleans", "title": "Booleans: true and false", "syntax": "bool ready = true;\nbool full = eggs > 10;   // 1 or 0",
		"about": "A boolean is a yes/no value: true or false. In C a comparison gives 1 for true and 0 for false, and that is also what printf shows with %d. Standard C needs #include <stdbool.h> for bool; in the kitchen it is always available.",
		"steps": ["Store a test in a bool to give it a clear name: bool ready = holding() != NOTHING;", "Use it later in an if: if (ready) { ... }", "Print it with %d to see 1 or 0."],
		"example": "void main() {\n    int eggs = 3;\n    bool enough = eggs >= 2;\n    printf(\"Enough eggs? %d\\n\", enough);\n    if (enough) {\n        printf(\"Let's cook!\\n\");\n    }\n}",
	},
	{
		"id": "if", "title": "if / else if / else", "syntax": "if (test) {\n    ...\n} else if (other) {\n    ...\n} else {\n    ...\n}",
		"about": "if runs its block only when the test is true. else if checks another test when the first was false. else runs when no test was true. Great for picking what to cook for an order.",
		"steps": ["Write the test in ( ) after if.", "Put the steps for that case in { }.", "Add else if / else for the other cases."],
		"example": "void main() {\n    int order = take_order();\n    if (order == EGSILOG) {\n        printf(\"Egsilog!\\n\");\n    } else if (order == HOTSILOG) {\n        printf(\"Hotsilog!\\n\");\n    } else {\n        printf(\"Something else\\n\");\n    }\n}",
	},
	{
		"id": "switch", "title": "switch", "syntax": "switch (value) {\n    case A:\n        ...\n        break;\n    case B:\n        ...\n        break;\n    default:\n        ...\n}",
		"about": "switch picks one of many blocks to run by comparing one value with each case. It is a tidy replacement for a long if / else if chain that keeps checking the same variable, such as the dish in an order.",
		"steps": ["Put the value to check in ( ) after switch.", "Write case VALUE: for each possibility, with its steps under it.", "End each case with break; and add default: for anything else."],
		"example": "void main() {\n    int order = take_order();\n    switch (order) {\n        case EGSILOG:\n            printf(\"Egsilog\\n\");\n            break;\n        case HOTSILOG:\n            printf(\"Hotsilog\\n\");\n            break;\n        default:\n            printf(\"Other: %s\\n\", order);\n    }\n}",
	},
	{
		"id": "while", "title": "while loop", "syntax": "while (test) {\n    ...\n}",
		"about": "A while loop repeats its block as long as the test stays true. Make sure something inside changes, or the loop never ends (the game stops endless loops for you).",
		"steps": ["Write the test that should keep the loop going.", "Put the repeated steps in { }.", "Change something inside so the test becomes false one day."],
		"example": "void main() {\n    int made = 0;\n    while (made < 3) {\n        go_to(FRIDGE);\n        pick_up(EGG);\n        go_to(GRILL);\n        cook();\n        go_to(ASSEMBLY);\n        plate();\n        made++;\n    }\n}",
	},
	{
		"id": "dowhile", "title": "do-while loop", "syntax": "do {\n    ...\n} while (test);",
		"about": "Like while, but the test is checked after the block, so the block always runs at least once. Note the ; after the closing ).",
		"steps": ["Write do { and the steps.", "Close with } while (test);", "Use it when the steps must happen once before you can check."],
		"example": "void main() {\n    int tries = 0;\n    do {\n        tries++;\n        printf(\"Try %d\\n\", tries);\n    } while (tries < 2);\n}",
	},
	{
		"id": "for", "title": "for loop", "syntax": "for (int i = 0; i < n; i++) {\n    ...\n}",
		"about": "A for loop counts. It has three parts: a start (int i = 0), a test (i < n) and a step (i++). The block runs once per count, perfect for 'make 3 of these'.",
		"steps": ["Start a counter: int i = 0", "Say how long to go: i < 3", "Count up each time: i++ and put the repeated steps in { }."],
		"example": "void main() {\n    for (int i = 0; i < 2; i++) {\n        go_to(FRIDGE);\n        pick_up(EGG);\n        go_to(STOVE);\n        cook();\n        go_to(ASSEMBLY);\n        plate();\n    }\n}",
	},
	{
		"id": "break", "title": "break and continue", "syntax": "break;     continue;",
		"about": "Inside a loop, break leaves the loop right away. continue skips the rest of this round and goes to the next one.",
		"steps": ["Put an if inside the loop.", "Use break to stop early (for example when there are no orders).", "Use continue to skip one round."],
		"example": "void main() {\n    for (int i = 0; i < 10; i++) {\n        if (i == 5) break;\n        if (i % 2 == 0) continue;\n        printf(\"%d \", i);\n    }\n}",
	},
	{
		"id": "functions", "title": "Your own functions", "syntax": "void name(int item) {\n    ...\n}\n\nint twice(int x) {\n    return x * 2;\n}",
		"about": "A function is a named group of steps you can call many times. Parameters (int item) pass values in, return sends a value back. Save useful ones in your Library (L) so every staff member can call them.",
		"steps": ["Write the return type (void if nothing comes back), a name and the parameters.", "Put the steps in { }; use return to give back a value.", "Call it from main(): fetch_and_cook(EGG);"],
		"example": "void fetch_and_cook(int item) {\n    go_to(FRIDGE);\n    pick_up(item);\n    go_to(GRILL);\n    cook();\n    go_to(ASSEMBLY);\n    plate();\n}\n\nvoid main() {\n    fetch_and_cook(RICE);\n    fetch_and_cook(EGG);\n    assemble(EGSILOG);\n}",
	},
	{
		"id": "params", "title": "Parameters and return", "syntax": "int add(int a, int b) {\n    return a + b;\n}\n\nint sum = add(2, 3);",
		"about": "Parameters are the names in the function's ( ) that receive values; the values you pass when calling are the arguments. A function that gives a value back has a type (like int) instead of void and uses return.",
		"steps": ["List parameters with their types, separated by commas: (int item, int station)", "Pass the same number of arguments in the same order when calling.", "Use return to send a value back, and store it in a variable."],
		"example": "int price_of_two(int price) {\n    return price * 2;\n}\n\nvoid cook_at(int item, int station) {\n    go_to(FRIDGE);\n    pick_up(item);\n    go_to(station);\n    cook();\n}\n\nvoid main() {\n    cook_at(EGG, STOVE);\n    printf(\"%d\\n\", price_of_two(30));\n}",
	},
	{
		"id": "names", "title": "Kitchen names", "syntax": "FRIDGE  GRILL  EGG  RICE  EGSILOG  NOTHING ...",
		"about": "Stations (FRIDGE, GRILL...), ingredients (EGG, RICE...) and dishes (EGSILOG...) are built-in names for numbers. You can store them in int variables, compare them and pass them to functions. NOTHING means empty hands. They can't be changed.",
		"steps": ["Use station names with go_to().", "Use ingredient names with pick_up() and stock().", "Use dish names with assemble() and to compare with take_order()."],
		"example": "void main() {\n    int station = GRILL;\n    go_to(station);\n    if (holding() == NOTHING) {\n        printf(\"Hands are empty\\n\");\n    }\n}",
	},
	{
		"id": "arrays", "title": "Arrays", "syntax": "int prices[] = {30, 40, 45};\nint counts[5];\nprices[0] = 35;",
		"about": "An array stores many values of the same type in one variable. Each value has an index in [ ], starting at 0. Arrays and for loops go together: the loop variable becomes the index.",
		"steps": ["Create one with a list, int a[] = {1, 2, 3};, or a size, int a[5];", "Read or change one item with its index: a[0] = 9;", "Loop over it: for (int i = 0; i < 3; i++) { ... a[i] ... }"],
		"example": "void main() {\n    int prices[] = {30, 40, 45};\n    int total = 0;\n    for (int i = 0; i < 3; i++) {\n        total += prices[i];\n    }\n    printf(\"Total %d\\n\", total);\n}",
	},
	{
		"id": "sizeof", "title": "Array size: sizeof", "syntax": "int n = sizeof(a) / sizeof(a[0]);",
		"about": "sizeof gives a size in bytes: an int is 4 bytes, so an array of 5 ints is 20. Dividing by the size of one item gives the number of items, so loops adapt when the list changes.",
		"steps": ["sizeof(a) is the whole array in bytes.", "sizeof(a[0]) is one item in bytes.", "Divide them to get the length."],
		"example": "void main() {\n    int a[] = {3, 1, 4, 1, 5};\n    int n = sizeof(a) / sizeof(a[0]);\n    printf(\"%d items\\n\", n);\n}",
	},
	{
		"id": "arrays2d", "title": "2D arrays", "syntax": "int grid[2][3] = {\n    {1, 2, 3},\n    {4, 5, 6}\n};\ngrid[1][2] = 9;",
		"about": "A 2D array is a table of rows and columns. The first [ ] picks the row, the second the column. Loop through it with one loop per dimension (a loop inside a loop).",
		"steps": ["Declare rows and columns: int grid[2][3];", "Give each row its own { } in the list.", "Use grid[row][col], with two nested for loops."],
		"example": "void main() {\n    int sales[2][3] = {{4, 2, 1}, {3, 5, 0}};\n    for (int r = 0; r < 2; r++) {\n        for (int c = 0; c < 3; c++) {\n            printf(\"%d \", sales[r][c]);\n        }\n        printf(\"\\n\");\n    }\n}",
	},
	{
		"id": "scope", "title": "Scope: local and global", "syntax": "int served = 0;   // global\n\nvoid f() {\n    int bonus = 5;  // local\n}",
		"about": "A variable made inside a function (or a { } block) is local: only that code can use it. A variable made outside all functions is global: every function can use and change it.",
		"steps": ["Prefer local variables; pass values with parameters.", "Use a global only for things every function shares, like a day's total.", "Don't give a local and a global the same name."],
		"example": "int served = 0;\n\nvoid count_one() {\n    served++;\n}\n\nvoid main() {\n    count_one();\n    count_one();\n    printf(\"%d\\n\", served);\n}",
	},
	{
		"id": "notsupported", "title": "Not in this kitchen", "syntax": "pointers, struct, malloc, strings",
		"about": "Byte n' Bite teaches the basics, so pointers (int *p), struct, malloc and text strings (char name[] = \"Miso\") are not used here. The game will tell you if one sneaks into your program.",
		"steps": ["Use functions to keep long programs tidy."],
		"example": "void main() {\n    int first = EGG;\n    int second = RICE;\n    printf(\"%s %s\\n\", first, second);\n}",
	},
]

## Extra help for kitchen functions (the signature and level come from c_builtins.gd).
const KITCHEN := {
	"go_to": {
		"about": "Walks the staff member to a station, stopping exactly in front of it (centred just below it) and turning to face it. They find their own way around tables and counters. The next line of your program runs only after they arrive. Most other kitchen functions only work at the right station, so go_to() comes first.",
		"steps": ["Choose the station: FRIDGE to get ingredients, GRILL / STOVE / FRYER to cook, ASSEMBLY to plate and assemble.", "Write go_to(GRILL); with the station name in capitals.", "Put the work for that station on the next lines (cook();, plate();...).", "If two staff go to the same station, the second stands beside the first."],
		"example": "void main() {\n    go_to(FRIDGE);\n    pick_up(EGG);\n    go_to(GRILL);   // walks to the grill and faces it\n    cook();\n}",
		"mistakes": ["Lower-case names: go_to(grill) fails. Station names are UPPERCASE.", "Using an ingredient instead of a station: go_to(EGG).", "Asking for a station this restaurant doesn't have yet (the error tells you)."],
		"related": ["pick_up", "cook", "plate"],
	},
	"pick_up": {
		"about": "Takes one ingredient into the staff member's hands. They must be standing at a station that stores it: the FRIDGE has everything, and the Grand Restaurant also has a PANTRY, FREEZER, DRINKS_DISPENSER, PASTRY_CASE and SINK (water). Hands hold one thing at a time.",
		"steps": ["go_to(FRIDGE); first.", "pick_up(EGG); with the ingredient name in capitals.", "Cook it if it needs cooking, then plate() it before picking up the next ingredient."],
		"example": "void main() {\n    go_to(FRIDGE);\n    pick_up(RICE);\n    printf(\"Holding %s\\n\", holding());\n}",
		"mistakes": ["Hands already full: plate() or trash() what you hold first.", "Not at a storage station: go_to(FRIDGE) first.", "Picking up a dish (EGSILOG): dishes are made with assemble(), not picked up."],
		"related": ["go_to", "holding", "plate"],
	},
	"cook": {
		"about": "Cooks the raw ingredient being held, at the current station. Each station cooks certain things: GRILL (rice, egg, hotdog, tocino, bread, patty), STOVE (noodles, egg, chocolate), FRYER (chicken), RICE_COOKER (rice), COFFEE_MACHINE brews COFFEE and MATCHA, OVEN bakes DOUGH. Fresh ingredients (LETTUCE, TOMATO, CHEESE, MILK...) don't need cooking. The staff member stays busy while it cooks.",
		"steps": ["Hold a raw ingredient that needs cooking.", "go_to() a station that cooks it (the Recipe Book lists where).", "cook(); then go_to(ASSEMBLY); and plate();"],
		"example": "void main() {\n    go_to(FRIDGE);\n    pick_up(EGG);\n    go_to(STOVE);\n    cook();\n    go_to(ASSEMBLY);\n    plate();\n}",
		"mistakes": ["Cooking at the wrong station (the error names the right one).", "Cooking something fresh like LETTUCE: just plate() it.", "Cooking twice: it's already cooked."],
		"related": ["cook_station", "doneness", "plate"],
	},
	"plate": {
		"about": "At the ASSEMBLY, puts the held ingredient onto this staff member's plate and frees their hands. Ingredients that need cooking must be cooked first. A plate collects every ingredient of a recipe; then assemble() turns it into the dish.",
		"steps": ["go_to(ASSEMBLY);", "plate(); puts what you're holding on your plate.", "Repeat for every ingredient in the recipe (some need two, like 2 EGGs).", "assemble(DISH); when the plate is complete."],
		"example": "void main() {\n    go_to(FRIDGE);\n    pick_up(LETTUCE);\n    go_to(ASSEMBLY);\n    plate();   // fresh, no cooking\n}",
		"mistakes": ["Plating raw food that needs cooking.", "Not at the ASSEMBLY.", "Plating with empty hands."],
		"related": ["assemble", "cook"],
	},
	"assemble": {
		"about": "At the ASSEMBLY, turns the plate into a finished dish. The plate must hold exactly the recipe's ingredients: nothing missing and nothing extra. If it doesn't match, the error lists what is missing or extra. After assembling, the staff member holds the dish, ready to serve().",
		"steps": ["Plate every ingredient the recipe needs.", "assemble(EGSILOG); with the dish name.", "serve(); to carry it to the customer."],
		"example": "void main() {\n    // ...plate RICE and EGG first...\n    go_to(ASSEMBLY);\n    assemble(EGSILOG);\n    serve();\n}",
		"mistakes": ["A missing or extra ingredient on the plate.", "A dish that isn't on your menu yet.", "Holding something while assembling: plate() it first."],
		"related": ["plate", "serve", "recipe"],
	},
	"serve": {
		"about": "Carries the finished dish you're holding to the customer who ordered it and hands it over. They pay its price, you gain EXP, and they show a face for how long they waited. A customer only accepts food after someone has taken their order. A dish nobody has ordered (or whose order hasn't been taken) waits on the SERVING_COUNTER (up to 6) until it is.",
		"steps": ["assemble() a dish first.", "serve(); the staff member walks to the customer by themselves.", "From Level 2, take_order() first (or check_counter() if a waiter posts tickets) so you cook what a customer wants."],
		"example": "void main() {\n    // ...assemble a dish first...\n    serve();\n}",
		"mistakes": ["Serving with empty hands or a plain ingredient.", "Cooking dishes nobody ordered until the counter is full."],
		"related": ["assemble", "take_order", "check_counter"],
	},
	"wait": {
		"about": "The staff member stands still for some seconds (0 to 60; decimals work). Use it inside loops while no orders are waiting, so the loop doesn't spin without doing anything.",
		"steps": ["Write the number of seconds in ( ): wait(1);", "In a loop: if there is no order, wait(1); then check again."],
		"example": "void main() {\n    while (1) {\n        if (has_order()) {\n            printf(\"Order!\\n\");\n        } else {\n            wait(1);\n        }\n    }\n}",
		"mistakes": ["More than 60 seconds or a negative number."],
		"related": ["has_order"],
	},
	"holding": {
		"about": "Returns what the staff member is holding (an ingredient or dish name), or NOTHING if their hands are empty. It's a function that returns a value, so store it in a variable or use it in a condition.",
		"steps": ["Compare it: if (holding() == EGG) { ... }", "Or store it: int h = holding();", "Print it with %s: printf(\"%s\\n\", holding());"],
		"example": "void main() {\n    go_to(FRIDGE);\n    pick_up(EGG);\n    if (holding() == EGG) {\n        printf(\"Got the egg\\n\");\n    }\n}",
		"mistakes": ["Using = instead of == in the comparison."],
		"related": ["pick_up", "is_burnt"],
	},
	"take_order": {
		"about": "Walks the staff member to the customer who has waited longest and whose order nobody has taken, asks what they want, and returns the dish (like EGSILOG). The customer's bubble changes from ? to the dish, and they calm down (patience drains at half speed). Returns NOTHING straight away when nobody is waiting. The staff member who took the order is the one making it, unless they post it to the counter with post_order().",
		"steps": ["Store the answer: int order = take_order();", "Decide with if / else if or switch (order).", "Cook that dish, assemble(order); and serve(); (or, as a waiter, go_to(SERVING_COUNTER); post_order(order);)."],
		"example": "void main() {\n    int order = take_order();\n    switch (order) {\n        case EGSILOG:\n            printf(\"Egsilog!\\n\");\n            break;\n        case NOTHING:\n            printf(\"Nobody is waiting\\n\");\n            break;\n        default:\n            printf(\"Making %s\\n\", order);\n    }\n}",
		"mistakes": ["Calling take_order() twice for one dish: the second call walks to ANOTHER customer.", "Not handling NOTHING when nobody is waiting.", "Cooking without taking the order: customers only accept food after they have ordered."],
		"related": ["has_order", "post_order", "serve"],
	},
	"trash": {
		"about": "At the TRASH, throws away whatever the staff member is holding, for example burnt food or a wrong ingredient. Their hands are empty afterwards.",
		"steps": ["go_to(TRASH);", "trash();"],
		"example": "void main() {\n    if (is_burnt()) {\n        go_to(TRASH);\n        trash();\n    }\n}",
		"mistakes": ["Not at the TRASH.", "Nothing in your hands."],
		"related": ["is_burnt"],
	},
	"is_burnt": {
		"about": "Returns 1 if the food you hold is burnt, otherwise 0. Use it in an if after cooking to decide whether to throw it away.",
		"steps": ["cook(); something.", "if (is_burnt()) { go_to(TRASH); trash(); }"],
		"example": "void main() {\n    go_to(FRIDGE);\n    pick_up(EGG);\n    go_to(GRILL);\n    cook();\n    if (is_burnt()) {\n        printf(\"Oops, burnt\\n\");\n    }\n}",
		"mistakes": ["Writing is_burnt without ( )."],
		"related": ["trash", "doneness"],
	},
	"stock": {
		"about": "Returns how many of an ingredient the kitchen has. Every pick_up() uses one; the manager buys more at the Market and claims the crates in the delivery area. Check it before cooking so you don't run out in the middle of a dish.",
		"steps": ["stock(EGG) gives a number.", "Compare it: if (stock(EGG) > 0) { ... }", "Use it as a loop condition: while (stock(EGG) > 0) { ... }"],
		"example": "void main() {\n    if (stock(EGG) > 0) {\n        printf(\"%d eggs left\\n\", stock(EGG));\n    }\n}",
		"mistakes": ["Passing a dish or station instead of an ingredient."],
		"related": ["pick_up"],
	},
	"has_order": {
		"about": "Returns 1 while a customer is waiting for someone to take their order, otherwise 0. It's the natural condition for a waiter's loop. (Tickets already on the counter don't count; check_counter() tells a cook about those.)",
		"steps": ["while (has_order()) { ... } keeps going while orders wait.", "Or inside while (1): if (has_order()) { ... } else { wait(1); }"],
		"example": "void main() {\n    while (has_order()) {\n        int order = take_order();\n        printf(\"Next: %s\\n\", order);\n    }\n}",
		"mistakes": ["A while (has_order()) loop ends when orders run out; use while (1) with wait(1) to keep working all day."],
		"related": ["take_order", "wait"],
	},
	"post_order": {
		"about": "At the SERVING_COUNTER, pins the order you took as a numbered paper ticket at the BACK of the queue. This is how a waiter hands orders to the cooks: the waiter only takes orders and posts them; cooks pick tickets up with check_counter(). The ticket keeps track of which customer ordered it, so serve() still finds them.",
		"steps": ["Take an order first: int order = take_order();", "go_to(SERVING_COUNTER);", "post_order(order); the ticket number is returned (1, 2, 3...)."],
		"example": "// Waiter: takes orders and posts them all day\nvoid main() {\n    while (1) {\n        if (has_order()) {\n            int order = take_order();\n            go_to(SERVING_COUNTER);\n            post_order(order);\n        } else {\n            wait(1);\n        }\n    }\n}",
		"mistakes": ["Not at the SERVING_COUNTER.", "Posting a dish you didn't take an order for.", "A waiter who posts and then also cooks the same order: once posted, it belongs to whichever cook checks the counter."],
		"related": ["take_order", "check_counter", "orders"],
	},
	"check_counter": {
		"about": "Walks to the SERVING_COUNTER and takes the OLDEST ticket (first in, first out, like a queue at a shop). Returns its dish, or NOTHING if there are no tickets. The ticket is removed from the counter, so two cooks never make the same order. Use it when another staff member works as the waiter.",
		"steps": ["int order = check_counter();", "if (order != NOTHING) { ...cook it, assemble(order); serve(); }", "In a while (1) loop, wait(1); when it returns NOTHING."],
		"example": "// Cook: makes whatever the waiter posted\nvoid main() {\n    while (1) {\n        int order = check_counter();\n        if (order == NOTHING) {\n            wait(1);\n        } else {\n            printf(\"Ticket: %s\\n\", order);\n        }\n    }\n}",
		"mistakes": ["Expecting tickets without a waiter: someone has to take_order() and post_order() first.", "Forgetting the NOTHING case, so the cook tries to make NOTHING."],
		"related": ["post_order", "take_order", "orders"],
	},
	"doneness": {
		"about": "Returns 0 to 100: how cooked the held food is. 100 means fully cooked.",
		"steps": ["Hold food that is cooking.", "Check doneness() in a loop or an if."],
		"example": "void main() {\n    printf(\"%d percent cooked\\n\", doneness());\n}",
		"mistakes": ["Calling it with empty hands (it returns 0)."],
		"related": ["cook", "flip"],
	},
	"flip": {
		"about": "At the GRILL, flips what is cooking.",
		"steps": ["go_to(GRILL);", "flip();"],
		"example": "void main() {\n    go_to(GRILL);\n    flip();\n}",
		"mistakes": ["Not at the GRILL."],
		"related": ["doneness", "cook"],
	},
	"recipe": {
		"about": "Fills an array with a dish's ingredients and returns how many there are. Each piece gets its own slot, so a Double Cheeseburger gives PATTY twice. Unused slots are set to NOTHING. Together with a for loop, it lets one program make any dish.",
		"steps": ["Make an array big enough for any dish: int items[8];", "int n = recipe(order, items);", "Loop: for (int i = 0; i < n; i++) { ... pick_up(items[i]); ... }"],
		"example": "void main() {\n    int items[8];\n    int n = recipe(HAMBURGER, items);\n    for (int i = 0; i < n; i++) {\n        printf(\"%s\\n\", items[i]);\n    }\n}",
		"mistakes": ["An array that's too small (the error says how big it must be).", "Passing items[0] instead of items: pass the whole array by name.", "Looping to 8 instead of n: the extra slots are NOTHING."],
		"related": ["cook_station", "take_order", "assemble"],
	},
	"cook_station": {
		"about": "Returns the station in this restaurant that cooks an ingredient, or NOTHING if it's served fresh. Use it with recipe() so a loop knows where to cook each item.",
		"steps": ["int where = cook_station(items[i]);", "if (where != NOTHING) { go_to(where); cook(); }"],
		"example": "void main() {\n    printf(\"%s\\n\", cook_station(CHICKEN));   // FRYER\n    printf(\"%s\\n\", cook_station(LETTUCE));   // NOTHING\n}",
		"mistakes": ["Passing a dish instead of an ingredient."],
		"related": ["recipe", "cook"],
	},
	"orders": {
		"about": "Copies the dishes on the counter's tickets into an array, oldest first, and returns how many it copied. The rest of the array is set to NOTHING. It only looks: the tickets stay on the counter. Handy for planning, such as counting how many burgers are waiting.",
		"steps": ["Make an array: int list[10];", "int n = orders(list);", "Loop: for (int i = 0; i < n; i++) { ... list[i] ... }"],
		"example": "void main() {\n    int list[10];\n    int n = orders(list);\n    int burgers = 0;\n    for (int i = 0; i < n; i++) {\n        if (list[i] == HAMBURGER) {\n            burgers++;\n        }\n    }\n    printf(\"%d tickets, %d burgers\\n\", n, burgers);\n}",
		"mistakes": ["Passing list[0] instead of list.", "Looping to the array size instead of n."],
		"related": ["check_counter", "recipe"],
	},
}


## All entries in book order: C basics first, then kitchen functions by level.
## "Syntax explained" notes for each C topic, written in our own words after
## the W3Schools C Tutorial (https://www.w3schools.com/c/), with a link to the
## matching W3Schools lesson for more reading.
const W3_BASE := "https://www.w3schools.com/c/"
const W3 := {
	"main": {"url": "c_syntax.php", "points": [
		"main() is where every C program starts running.",
		"The code that main() runs goes between the curly brackets { }.",
		"Every statement (one instruction) ends with a semicolon ;",
		"Spaces and new lines don't change the meaning; use them to keep code readable.",
		"#include <stdio.h> brings in printf(); in the kitchen it is already included."]},
	"comments": {"url": "c_comments.php", "points": [
		"Comments are notes for people; the computer ignores them.",
		"// starts a single-line comment that lasts to the end of the line.",
		"/* starts a multi-line comment and */ ends it.",
		"Putting // in front of a line switches it off while you test."]},
	"variables": {"url": "c_variables.php", "points": [
		"A variable is a container that stores a value, like a number or a letter.",
		"Create one with: type name = value;  for example  int eggs = 2;",
		"You can create it first and give it a value later: int eggs;  eggs = 2;",
		"Giving it a new value replaces the old one.",
		"Choose names that say what the value means (eggs, not x)."]},
	"datatypes": {"url": "c_data_types.php", "points": [
		"int stores whole numbers such as 3 or -12.",
		"float stores decimals (about 6-7 digits); double stores more exact decimals (about 15 digits).",
		"char stores a single letter in single quotes: 'A'.",
		"Each type has its own format specifier for printf: %d, %f, %lf, %c."]},
	"printf": {"url": "c_variables_format.php", "points": [
		"printf() prints text; the text goes inside double quotes.",
		"Format specifiers are placeholders that start with %: %d for int, %f for float, %c for char.",
		"After the text, list the values separated by commas, in the same order as the placeholders.",
		"\\n inside the text starts a new line; %.2f shows 2 decimals."]},
	"math": {"url": "c_operators.php", "points": [
		"Arithmetic operators: + add, - subtract, * multiply, / divide, % remainder.",
		"++ adds 1 to a variable and -- takes 1 away.",
		"Assignment operators combine a calculation with storing: x += 3 is the same as x = x + 3.",
		"Dividing two ints drops the decimal part: 7 / 2 is 3."]},
	"compare": {"url": "c_operators_comparison.php", "points": [
		"Comparison operators compare two values: ==, !=, >, <, >=, <=.",
		"The result is 1 (true) or 0 (false).",
		"== compares; a single = stores a value. Mixing them up is a common mistake.",
		"Logical operators join tests: && (and: both true), || (or: at least one true), ! (not: flips the result)."]},
	"booleans": {"url": "c_booleans.php", "points": [
		"A boolean can only be true or false.",
		"In standard C, bool needs #include <stdbool.h>.",
		"Printed with %d, true shows 1 and false shows 0.",
		"Comparisons give boolean results, so you can store them: bool hot = temp > 80;"]},
	"if": {"url": "c_conditions.php", "points": [
		"if runs its block only when the condition in ( ) is true.",
		"else runs a block when the condition is false.",
		"else if checks a new condition when the one before was false.",
		"if, else and else if are written in lowercase; If or IF is an error.",
		"Short hand: variable = (test) ? value_if_true : value_if_false;"]},
	"switch": {"url": "c_switch.php", "points": [
		"switch checks one value against many possible cases.",
		"The value in switch ( ) is compared with each case; the matching case's code runs.",
		"break leaves the switch. Without it, the code keeps running into the next case.",
		"default (optional) runs when no case matches.",
		"case values must be fixed values: numbers, letters in quotes, or kitchen names."]},
	"while": {"url": "c_while_loop.php", "points": [
		"A loop repeats a block of code as long as its condition is true.",
		"while checks the condition first, so the block may run zero times.",
		"Change the variable used in the condition inside the loop, otherwise the loop never ends."]},
	"dowhile": {"url": "c_do_while_loop.php", "points": [
		"do/while is a variant of while.",
		"It runs the block once before checking the condition.",
		"So the block always runs at least once, even when the condition is false.",
		"Remember the ; after while (condition)."]},
	"for": {"url": "c_for_loop.php", "points": [
		"Use for when you know how many times to repeat.",
		"Statement 1 (int i = 0) runs once, before the loop starts.",
		"Statement 2 (i < 5) is the condition checked before each round.",
		"Statement 3 (i++) runs after every round, usually to count.",
		"You can count by other steps (i += 2) or count down (i--)."]},
	"break": {"url": "c_break_continue.php", "points": [
		"break jumps out of the loop completely.",
		"continue skips the rest of this round and goes on with the next one.",
		"Both work in for, while and do/while loops."]},
	"functions": {"url": "c_functions.php", "points": [
		"A function is a block of code that only runs when it is called.",
		"Some functions are predefined (printf, and the kitchen's cook()); you can also create your own.",
		"To create one: return type, name, ( ) and { }: void greet() { ... }",
		"void means the function gives nothing back.",
		"Call it with its name, ( ) and a semicolon: greet();  You can call it many times."]},
	"params": {"url": "c_functions_parameters.php", "points": [
		"Parameters act as variables inside the function; they are listed in the ( ) with their types.",
		"The values you pass when calling are arguments.",
		"Several parameters are separated by commas; arguments must match their number and order.",
		"Use a type like int instead of void, and the return keyword, to send a value back.",
		"Store the returned value in a variable or use it directly."]},
	"names": {"url": "c_constants.php", "points": [
		"Kitchen names work like C constants: fixed values that can't be changed.",
		"They are written in UPPERCASE so they stand out from variables.",
		"Each one stands for a number, so it fits in an int variable."]},
	"arrays": {"url": "c_arrays.php", "points": ["An array holds many values of one type in a single variable.", "Write the values in { } separated by commas; C counts them if you leave [ ] empty.", "Indexes start at 0: the first item is [0], the last is [size - 1].", "Change an item with its index: a[0] = 33;", "The size can't change after the array is made."]},
	"sizeof": {"url": "c_arrays_size.php", "points": ["sizeof returns a size in bytes, not a count of items.", "An int is 4 bytes, so 5 ints are 20 bytes.", "sizeof(a) / sizeof(a[0]) gives the number of items, for any type.", "Use it as the loop limit so the loop always fits the array."]},
	"arrays2d": {"url": "c_arrays_multi.php", "points": ["A 2D array is a table (matrix) of rows and columns.", "The first number is the rows, the second the columns: int m[2][3];", "Read a cell with m[row][col]; both start at 0.", "Use one loop for each dimension: rows outside, columns inside."]},
	"scope": {"url": "c_scope.php", "points": ["A variable created inside a function belongs to that function (local scope).", "A variable created outside functions is global and usable everywhere.", "Avoid using the same name for a local and a global variable."]},
	"notsupported": {"url": "c_arrays.php", "points": [
		"Pointers, structs and strings are real C features you can learn later on W3Schools.",
		"Byte n' Bite keeps to variables, operators, conditions, switch, loops, arrays and functions so you can master the basics first."]},
}

## Functions that give back a value (used to explain how to use them).
const RETURNS := ["holding", "take_order", "is_burnt", "stock", "has_order", "doneness", "recipe", "cook_station", "post_order", "check_counter", "orders"]
const ARG_HELP := {
	"STATION": "a station name such as FRIDGE or GRILL",
	"INGREDIENT": "an ingredient name such as EGG or RICE",
	"DISH": "a dish name such as EGSILOG",
	"seconds": "a number of seconds, such as 2 or 0.5",
	"DISH, items": "a dish name and an array to fill, such as recipe(EGSILOG, items)",
	"list": "an array to fill, such as int list[10];",
}


## How a kitchen function's syntax works, in the same terms as the C lessons.
static func kitchen_points(fname: String, sig: String) -> Array:
	var pts: Array = []
	var arg := sig.get_slice("(", 1).trim_suffix(")")
	pts.append("%s is a predefined function, like printf(): you call it by writing its name followed by ( )." % fname)
	if "," in arg:
		pts.append("Inside the ( ) go two arguments separated by a comma: %s." % ARG_HELP.get(arg, arg))
	elif arg != "":
		pts.append("Inside the ( ) goes one argument: %s. A variable holding that value works too." % ARG_HELP.get(arg, arg))
	else:
		pts.append("It takes no arguments, so the ( ) stay empty.")
	if fname in RETURNS:
		pts.append("It returns a value, so store it in a variable (int x = %s;) or use it in a test (if (%s == ...))." % [fname + "(" + ("" if arg == "" else arg) + ")", fname + "(" + ("" if arg == "" else arg) + ")"])
	else:
		pts.append("It returns nothing (like a void function), so it is used as its own statement.")
	pts.append("As a statement it ends with a semicolon ;")
	return pts


## Which lesson teaches each C topic (the Kitchen Functions list is grouped by it).
const LESSON_OF := {"main": 1, "comments": 1, "printf": 1, "variables": 1, "datatypes": 1, "math": 1, "names": 1, "compare": 2, "booleans": 2, "if": 2, "switch": 2, "while": 3, "dowhile": 3, "for": 3, "break": 3, "arrays": 4, "sizeof": 4, "arrays2d": 4, "functions": 5, "params": 5, "scope": 5, "notsupported": 5}
const LESSON_NAMES := ["Basics", "Decisions", "Loops", "Arrays", "Functions"]


static func entries() -> Array:
	var out: Array = []
	var sorted: Array = BASICS.duplicate()
	sorted.sort_custom(func(a, b): return LESSON_OF.get(a.id, 5) < LESSON_OF.get(b.id, 5))
	for e in sorted:
		var d: Dictionary = e.duplicate()
		d.group = "Lesson %d · %s" % [LESSON_OF.get(d.id, 5), LESSON_NAMES[LESSON_OF.get(d.id, 5) - 1]]
		d.level = 1
		var w: Dictionary = W3.get(d.id, {})
		d.points = w.get("points", [])
		d.w3 = (W3_BASE + w.url) if w.has("url") else ""
		out.append(d)
	for fname in Builtins.FUNCS:
		var f: Dictionary = Builtins.FUNCS[fname]
		if f.get("hidden", false):
			continue
		var h: Dictionary = KITCHEN.get(fname, {})
		out.append({
			"id": fname, "title": fname + "()", "group": "Kitchen · Level %d" % f.level,
			"level": f.level, "syntax": f.sig + ";",
			"about": h.get("about", f.desc), "steps": h.get("steps", []),
			"example": h.get("example", "void main() {\n    %s;\n}" % f.sig),
			"points": kitchen_points(fname, f.sig),
			"mistakes": h.get("mistakes", []),
			"related": h.get("related", []),
			"w3": W3_BASE + ("c_arrays.php" if fname in ["recipe", "cook_station", "orders"] else ("c_functions_parameters.php" if fname in RETURNS or f.args > 0 else "c_functions.php")),
		})
	return out
