/**
 * \file knn.cpp
 *
 * \date 18 Oct 2016
 * \author adamfowler
 */

#include <MarkLogic.h>
#include <cmath>
#include <string>
#include <sstream>
#include <vector>
#include <functional>
#include <iostream>
#include <istream>

#ifdef _MSC_VER
#define PLUGIN_DLL __declspec(dllexport)
#else // !_MSC_VER
#define PLUGIN_DLL
#endif

using namespace marklogic;

struct Match {
  String uri;
  double score;
};

/**
 * \brief This UDF calculates the k nearest neighbours for a given record
 */
class kNNUDF : public AggregateUDF {
public:

  AggregateUDF* clone() const {
    return (new kNNUDF(*this));  // calls copy constructor
  }

  void start(Sequence& args, Reporter& reporter) {
    bestScore = 100000;
    std::string candidateUri = "";
    k = 1;
    try {
      int argc = 0;
      for (; !args.done(); args.next()) {

        if (0 == argc) {
          String argValue;
          args.value(argValue);
          std::string arg = std::string(argValue);
          candidateUri = arg;
        } else {
          // argc == 1 -> k value
          if (1 == argc) {
            args.value(k);
          } else {

            double dbl;
            args.value(dbl);
            // assume double for our purposes
            // TODO support other range index types (dates, times, etc.)
            candidateValues.push_back(dbl);
          }
        }

        argc++;
      } // end for

      bestMatches.reserve(k);
    } catch (std::exception& ex) {
      reporter.error(("Exception in start(): " + std::string(ex.what())).c_str());
    }
  }



  /**
   * \brief Get the values we need for the aggregate and cache them
   *
   * Assume the first column (index 0) is the group by field (with LOW cardinality)
   */
  void map(TupleIterator& values, Reporter& reporter) {
    try {
      bool first = true;
      for (; !values.done(); values.next()) {
          double val;
          String uri;
          values.value(0,uri);

          uint64_t freq = values.frequency();
          double score = 1.0;
          // loop over value count too, for each of 1 to n (n > 0) parameters
          for (int v = 1;v < values.width();v++) { // ignore v = 0 as it's a URI
            values.value(v,val);
            score *= (1.0 + std::abs(candidateValues.at(v - 1) - val));
          }
          score = 1.0 / std::pow(score, (values.width() - 1)); // first is URI, so use one less
          /*
          std::ostringstream oss;
          oss << "map() uri: " << std::string(uri) << ", score: " << score;
          reporter.error(oss.str().c_str()); // Debug level doesn't seem to work...
*/
/*
          if (first) {
            first = false;

            std::ostringstream oss;
            oss << "Score: " << score << ", width: " << values.width();
            reporter.log(Reporter::Debug,oss.str().c_str());
          }*/

          count += freq;
          if (bestMatches.size() < k || bestMatches.at(0).score < score) {
            // remove front of vector matches
            if (bestMatches.size() == k) {
              bestMatches.erase(bestMatches.begin());
              // only erase if size is same as k value
            }
            // add a new vector match
            Match m;
            m.uri = uri;
            m.score = score;
            if (bestScore < score) {
              bestScore = score;
            }
            bestMatches.push_back(m);
          }
      }

    } catch (std::exception& ex) {
      reporter.error(("Exception in map(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Reduce down the values from another aggregate UDF instance, and copy in to this aggregate instance
   */
  void reduce(const AggregateUDF* otherAgg, Reporter& reporter) {
    try {
      // loop through other's values and add to our equivalent value (if exists)
      // if doesn't exist in our values, add to our values
      const kNNUDF* other = (const kNNUDF*)otherAgg;
      for (int i = 0;i < other->bestMatches.size();i++) {
        Match om = other->bestMatches.at(i);

        if (bestMatches.size() < k || bestMatches.at(0).score < om.score) {
          // remove front of vector matches
          if (bestMatches.size() == k) {
            bestMatches.erase(bestMatches.begin());
            // only erase if size is same as k value
          }
          // add a new vector match
          if (bestScore < om.score) {
            bestScore = om.score;
          }
          bestMatches.push_back(om); // forces copy constructor, just to be safe
        }
      }
      count += other->count;
    } catch (std::exception& ex) {
      reporter.error(("Exception in reduce(): " + std::string(ex.what())).c_str());
    }
  } // end reduce



  /**
   * \brief Encode to XDQP stream
   */
  void encode(Encoder& e, Reporter& reporter) {
    try {
      // encode bestMatches, bestScore, count
      e.encode(count);
      e.encode(bestScore);
      e.encode(bestMatches.size());
      for (int i = 0;i < bestMatches.size();i++) {
        Match m = bestMatches.at(i);

        e.encode(m.uri);
        e.encode(m.score);
      }
    } catch (std::exception& ex) {
      reporter.error(("Exception in encode(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Decode from XDQP stream
   */
  void decode(Decoder& d, Reporter& reporter) {
    try {
      //  decode bestMatches, bestScore, count
        d.decode(count);
        d.decode(bestScore);
        int32_t size;
        d.decode(size);
        for (int i = 0;i < size;i++) {
          Match m;

          d.decode(m.uri);
          d.decode(m.score);

          bestMatches.push_back(m);
        }



    } catch (std::exception& ex) {
      reporter.error(("Exception in decode(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Return the final result from the remaining aggregate UDF instance
   */
  void finish(OutputSequence& os, Reporter& reporter) {
    try {
      /*
      //std::ostringstream oss;
      //oss << "log[odds]  = " << (round(A*100) / 100) << " + " << (round(B*100) / 100) << " ln(x)";
      // write output
      os.startMap();
      for (int i = 0;i < bestMatches.size();i++) {
        Match m = bestMatches.at(i);

        os.writeMapKey(m.uri);
        os.writeValue(m.score);
      }

      // write out count too, at top level
      os.writeMapKey("count");
      os.writeValue(count);
      os.endMap();

*/

      for (int i = 0;i < bestMatches.size();i++) {
        Match m = bestMatches.at(i);

        os.writeValue(m.uri);
        /*
        std::ostringstream oss;
        oss << m.score;
        os.writeValue(String(oss.str().c_str()));
        */
      }

    } catch (std::exception& ex) {
      reporter.error(("Exception in finish(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Clear up resources from this aggregate UDF
   */
  void close() {
    // NOT SAFE TO DELETE ANYTHING - called multiple times
  }

private:
  std::vector<Match> bestMatches;
  std::vector<double> candidateValues;
  double bestScore;
  long count;
  int k;
};

extern "C" PLUGIN_DLL void marklogicPlugin(Registry& r) {
  r.version(1);
  r.registerAggregate<kNNUDF>("knn");
}
