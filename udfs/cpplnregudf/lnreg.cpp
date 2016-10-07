/**
 * \file lnreg.cpp
 *
 * \date 3 Oct 2016
 * \author adamfowler
 */

#include <MarkLogic.h>
#include <cmath>
#include <string>
#include <map>
#include <functional>
#include <iostream>
#include <istream>

#ifdef _MSC_VER
#define PLUGIN_DLL __declspec(dllexport)
#else // !_MSC_VER
#define PLUGIN_DLL
#endif

using namespace marklogic;


/**
 * \brief This UDF calculates the logarithmic regression (ln reg) between two fields over a search results data set (two tuples)
 */
class LnRegUDF : public AggregateUDF {
public:

  AggregateUDF* clone() const {
    return (new LnRegUDF(*this));  // calls copy constructor
  }

  void start(Sequence& args, Reporter& reporter) {
    sum0 = 0.0;sum1 = 0.0;sum2=0.0;sum3=0.0;count = 0;
    try {
      for (; !args.done(); args.next()) {
        String argValue;
        args.value(argValue);
        std::string arg = std::string(argValue);

      } // end for
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
      for (; !values.done(); values.next()) {
          double x,y;
          uint64_t freq = values.frequency();
          values.value(0,x);
          values.value(1,y);
          double logX = std::log(x);
          sum0 += freq * logX;
          sum1 += freq * y * logX;
          sum2 += freq * y;
          sum3 += freq * logX * logX;
          count += freq;
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
      const LnRegUDF* other = (const LnRegUDF*)otherAgg;
      sum0 += other->sum0;
      sum1 += other->sum1;
      sum2 += other->sum2;
      sum3 += other->sum3;
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
      e.encode(sum0);
      e.encode(sum1);
      e.encode(sum2);
      e.encode(sum3);
      e.encode(count);
    } catch (std::exception& ex) {
      reporter.error(("Exception in encode(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Decode from XDQP stream
   */
  void decode(Decoder& d, Reporter& reporter) {
    try {
      d.decode(sum0);
      d.decode(sum1);
      d.decode(sum2);
      d.decode(sum3);
      d.decode(count);
    } catch (std::exception& ex) {
      reporter.error(("Exception in decode(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Return the final result from the remaining aggregate UDF instance
   */
  void finish(OutputSequence& os, Reporter& reporter) {
    try {
      // calculate A, B, string
      double B = (count * sum1 - sum2 * sum0) / (count * sum3 - sum0 * sum0);
      double A = (sum2 - B * sum0) / count;
      //std::ostringstream oss;
      //oss << "y = " << (round(A*100) / 100) << " + " << (round(B*100) / 100) << " ln(x)";
      // write output
      os.startMap();
      os.writeMapKey("A");
      os.writeValue(A);
      os.writeMapKey("B");
      os.writeValue(B);
      //os.writeMapKey("string");
      //os.writeValue(oss.str());
      os.writeMapKey("count");
      os.writeValue(count);
      os.endMap();
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
  double sum0,sum1,sum2,sum3;
  long count;
};

extern "C" PLUGIN_DLL void marklogicPlugin(Registry& r) {
  r.version(1);
  r.registerAggregate<LnRegUDF>("lnreg");
}




