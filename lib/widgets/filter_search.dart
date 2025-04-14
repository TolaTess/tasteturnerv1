import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/ingredient_model.dart';
import 'secondary_button.dart';

class FilterSearch extends StatelessWidget {
  const FilterSearch({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FilterButton(
      //filter button
      press: () {
        showModalBottomSheet<dynamic>(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30), topRight: Radius.circular(30))),
          isScrollControlled: true,
          context: context,
          builder: (BuildContext context) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30))),
              child: ListView(
                children: [
                  const SizedBox(height: 30),
                  Text(
                    filterSearch,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Preparation Time title
                  Row(
                    children: [
                      Text(preparationTimeString,
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Preparation Time Filter
                  const PrepTimeFilter(),
                  const SizedBox(height: 15),

                  // Rating title
                  Row(
                    children: [
                      Text(rating,
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Rating filter
                  const RatingFilter(),
                  const SizedBox(height: 15),

                  // Category title
                  Row(
                    children: [
                      Text(category,
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Category filter
                  const CategoryFilter(),
                  const SizedBox(height: 20),

                  // Apply button
                  SecondaryButton(
                    text: apply,
                    press: () {
                      Navigator.pop(context);
                    },
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

//filter button

class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.press,
  });

  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color.fromARGB(255, 195, 15, 15),
        ),
        child: const Icon(
          Icons.tune,
          color: Colors.white,
        ),
      ),
    );
  }
}

//filter category

class CategoryFilter extends StatelessWidget {
  const CategoryFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 15,
        runSpacing: 15,
        children: [
          //generate chip list based on CategoryFilterChip
          ...List.generate(
              recipeCategory.length,
              (index) => CategoryFilterChip(
                    recipeCategory: recipeCategory[index],
                  ))
        ],
      ),
    );
  }
}

//build chip

class CategoryFilterChip extends StatefulWidget {
  const CategoryFilterChip({super.key, required this.recipeCategory});

  final String recipeCategory;

  @override
  State<CategoryFilterChip> createState() => _CategoryFilterChipState();
}

class _CategoryFilterChipState extends State<CategoryFilterChip> {
  bool _selected = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selected = !_selected;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        decoration: BoxDecoration(
            color: _selected ? kPrimaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kPrimaryColor)),
        child: Text(
          widget.recipeCategory,
          style: TextStyle(
              color: _selected ? Colors.white : kPrimaryColor,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

//filter prep time

class PrepTimeFilter extends StatelessWidget {
  const PrepTimeFilter({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 15,
        runSpacing: 15,
        children: [
          //generate chip list based on PrepTimeChip
          ...List.generate(preparationTime.length,
              (index) => PrepTimeChip(preparationTime: preparationTime[index]))
        ],
      ),
    );
  }
}

//build chip
class PrepTimeChip extends StatefulWidget {
  const PrepTimeChip({
    super.key,
    required this.preparationTime,
  });

  final String preparationTime;

  @override
  State<PrepTimeChip> createState() => _PrepTimeChipState();
}

class _PrepTimeChipState extends State<PrepTimeChip> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selected = !_selected;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        decoration: BoxDecoration(
            color: _selected ? kPrimaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kPrimaryColor)),
        child: Text(
          widget.preparationTime,
          style: TextStyle(
              color: _selected ? Colors.white : kPrimaryColor,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

//rating filter

class RatingFilter extends StatelessWidget {
  const RatingFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 15,
        runSpacing: 15,
        children: [
          //generate chip list based on RatingFilterChip
          ...List.generate(
            recipeRating.length,
            (index) => RatingFilterChip(
              recipeRating: recipeRating[index],
            ),
          )
        ],
      ),
    );
  }
}

//build chip
class RatingFilterChip extends StatefulWidget {
  const RatingFilterChip({super.key, required this.recipeRating});

  final String recipeRating;

  @override
  State<RatingFilterChip> createState() => _RatingFilterChipState();
}

class _RatingFilterChipState extends State<RatingFilterChip> {
  bool _selected = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selected = !_selected;
        });
      },
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: _selected ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kPrimaryColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.recipeRating,
              style: TextStyle(
                color: _selected ? Colors.white : kPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              width: 5,
            ),
            Icon(
              Icons.star,
              color: _selected ? Colors.white : kPrimaryColor,
            )
          ],
        ),
      ),
    );
  }
}
